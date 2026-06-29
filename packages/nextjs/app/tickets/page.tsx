"use client";

import { FormEvent, useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { Contract, formatEther, parseEther } from "ethers";
import type { NextPage } from "next";
import {
  ArrowLeftIcon,
  ArrowPathIcon,
  ArrowRightIcon,
  BanknotesIcon,
  ShoppingBagIcon,
  TicketIcon,
  XMarkIcon,
} from "@heroicons/react/24/outline";
import { useWallet } from "~~/hooks/eventra/useWallet";
import { getReadContract, getWriteContract, parseContractError } from "~~/utils/eventra/contract";

type TicketView = {
  id: number;
  eventId: number;
  eventName: string;
  eventDate: number;
  ticketPrice: bigint;
  priceEth: string;
  resellPrice: bigint;
  numberOfOwners: number;
  state: number;
};

type TicketAction = (contract: Contract) => Promise<{ wait: () => Promise<unknown> }>;

const TICKET_STATE = ["Activa", "Transferida", "En reventa", "Usada", "Cancelada", "Reembolsada"];

const TicketsPage: NextPage = () => {
  const { address, connect } = useWallet();
  const [tickets, setTickets] = useState<TicketView[] | null>(null);
  const [resellTickets, setResellTickets] = useState<TicketView[]>([]);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [transferTicket, setTransferTicket] = useState<TicketView | null>(null);
  const [transferTo, setTransferTo] = useState("");
  const [resellTicket, setResellTicket] = useState<TicketView | null>(null);
  const [resellPrice, setResellPrice] = useState("");

  const loadTickets = useCallback(async () => {
    if (!address) return;
    setLoading(true);
    setError(null);
    try {
      const signer = await connect();
      const userContract = getWriteContract(signer);
      const readContract = getReadContract();
      const getEvent = readContract.getFunction("getEvent");
      const userIds: bigint[] = await userContract.getAllUserTickets();
      const resellIds: bigint[] = await readContract.getTicketsInResell();

      const mapTicket = async (id: bigint): Promise<TicketView> => {
        const ticket = await userContract.getTicket(id);
        const ev = await getEvent(ticket.eventId);
        const resellPriceWei = await readContract.ticketResellPrice(id);

        return {
          id: Number(id),
          eventId: Number(ticket.eventId),
          eventName: ev.eventName,
          eventDate: Number(ev.eventDate) * 1000,
          ticketPrice: ev.ticketPrice as bigint,
          priceEth: formatEther(ev.ticketPrice),
          resellPrice: resellPriceWei as bigint,
          numberOfOwners: Number(ticket.numberOfOwners),
          state: Number(ticket.ticketState),
        };
      };

      const [owned, resell] = await Promise.all([
        Promise.all(userIds.map(mapTicket)),
        Promise.all(resellIds.map(mapTicket)),
      ]);

      setTickets(owned.sort((a, b) => b.id - a.id));
      setResellTickets(
        resell.filter(ticket => ticket.state === 2 && ticket.resellPrice > 0n).sort((a, b) => b.id - a.id),
      );
    } catch (e) {
      setError(parseContractError(e));
      setTickets([]);
      setResellTickets([]);
    } finally {
      setLoading(false);
    }
  }, [address, connect]);

  useEffect(() => {
    loadTickets();
  }, [loadTickets]);

  const runTicketAction = async (key: string, action: TicketAction) => {
    setBusy(key);
    setError(null);
    try {
      const signer = await connect();
      const contract = getWriteContract(signer);
      const tx = await action(contract);
      await tx.wait();
      await loadTickets();
    } catch (e) {
      setError(parseContractError(e));
    } finally {
      setBusy(null);
    }
  };

  const submitTransfer = (e: FormEvent) => {
    e.preventDefault();
    if (!transferTicket) return;
    runTicketAction(`transfer-${transferTicket.id}`, contract =>
      contract.transferTicket(transferTo, transferTicket.id),
    );
    setTransferTicket(null);
    setTransferTo("");
  };

  const submitResell = (e: FormEvent) => {
    e.preventDefault();
    if (!resellTicket) return;
    runTicketAction(`resell-${resellTicket.id}`, contract =>
      contract.putTicketInResell(resellTicket.id, parseEther(resellPrice)),
    );
    setResellTicket(null);
    setResellPrice("");
  };

  const buyResell = (ticket: TicketView) => {
    runTicketAction(`buy-resell-${ticket.id}`, contract =>
      contract.buyTicketFromResell(ticket.id, { value: ticket.resellPrice }),
    );
  };

  if (!address) {
    return (
      <div className="flex grow items-center justify-center bg-[#f5f6f8] px-4 py-10">
        <div className="w-full max-w-md rounded-2xl bg-white p-8 text-center shadow-md">
          <TicketIcon className="mx-auto h-11 w-11 text-[#2bb3ec]" strokeWidth={1.5} />
          <h1 className="mt-2 text-xl font-bold text-[#131a2b]">Conecta tu wallet</h1>
          <p className="mt-2 text-sm text-[#6b7280]">Necesitas conectar tu wallet para ver y gestionar tus tickets.</p>
          <button
            onClick={connect}
            className="mt-5 w-full cursor-pointer rounded-full bg-[#2bb3ec] py-3 font-semibold text-white shadow-md transition hover:bg-[#1ba5dd]"
          >
            Conectar wallet
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex grow flex-col items-center bg-[#f5f6f8] px-4 py-10">
      <div className="w-full max-w-4xl">
        <Link
          href="/"
          className="mb-4 inline-flex items-center gap-1 text-sm font-medium text-[#6b7280] hover:text-[#131a2b]"
        >
          <ArrowLeftIcon className="h-4 w-4" />
          Volver
        </Link>

        <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-2">
            <TicketIcon className="h-7 w-7 text-[#2bb3ec]" />
            <h1 className="text-2xl font-bold text-[#131a2b]">Mis tickets</h1>
          </div>
          <button
            onClick={loadTickets}
            disabled={loading}
            className="inline-flex cursor-pointer items-center justify-center gap-2 rounded-full border border-[#e5e7eb] bg-white px-4 py-2 text-sm font-semibold text-[#131a2b] transition hover:bg-[#f5f6f8] disabled:opacity-60"
          >
            <ArrowPathIcon className={`h-4 w-4 ${loading ? "animate-spin" : ""}`} />
            Actualizar
          </button>
        </div>

        {error && <div className="mb-4 rounded-lg bg-[#fdecec] px-3 py-2 text-sm text-[#b42424]">{error}</div>}
        {loading && <p className="text-center text-sm text-[#6b7280]">Cargando tickets...</p>}

        <section>
          <h2 className="mb-3 text-lg font-bold text-[#131a2b]">Tus entradas</h2>
          {tickets && tickets.length === 0 && (
            <div className="rounded-2xl bg-white p-8 text-center shadow-md">
              <p className="text-sm text-[#6b7280]">Todavia no tienes tickets en esta wallet.</p>
              <Link
                href="/events"
                className="mt-5 inline-flex items-center gap-2 rounded-full bg-[#2bb3ec] px-6 py-2.5 font-semibold text-white shadow-md transition hover:bg-[#1ba5dd]"
              >
                <ShoppingBagIcon className="h-5 w-5" />
                Ver eventos
              </Link>
            </div>
          )}

          {tickets && tickets.length > 0 && (
            <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
              {tickets.map(ticket => (
                <TicketCard
                  key={ticket.id}
                  ticket={ticket}
                  busy={busy}
                  onTransfer={() => setTransferTicket(ticket)}
                  onResell={() => setResellTicket(ticket)}
                  onRemoveResell={() =>
                    runTicketAction(`remove-${ticket.id}`, contract => contract.removeTicketFromResell(ticket.id))
                  }
                  onWithdraw={() =>
                    runTicketAction(`withdraw-${ticket.id}`, contract => contract.withdrawUserFunds(ticket.id))
                  }
                />
              ))}
            </div>
          )}
        </section>

        <section className="mt-10">
          <h2 className="mb-3 text-lg font-bold text-[#131a2b]">Reventa</h2>
          {resellTickets.length === 0 ? (
            <div className="rounded-2xl bg-white p-6 text-sm text-[#6b7280] shadow-md">
              No hay tickets en reventa ahora mismo.
            </div>
          ) : (
            <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
              {resellTickets.map(ticket => (
                <div key={ticket.id} className="rounded-2xl bg-white p-6 shadow-md">
                  <TicketHeader ticket={ticket} />
                  <div className="mt-4 grid grid-cols-2 gap-3 text-sm text-[#131a2b]">
                    <Info label="Precio reventa" value={`${formatEther(ticket.resellPrice)} ETH`} />
                    <Info label="Evento" value={new Date(ticket.eventDate).toLocaleDateString()} />
                  </div>
                  <button
                    onClick={() => buyResell(ticket)}
                    disabled={busy === `buy-resell-${ticket.id}`}
                    className="mt-5 flex w-full cursor-pointer items-center justify-center gap-2 rounded-full bg-[#2bb3ec] py-3 text-sm font-semibold text-white shadow-md transition hover:bg-[#1ba5dd] disabled:opacity-60"
                  >
                    <ShoppingBagIcon className="h-5 w-5" />
                    {busy === `buy-resell-${ticket.id}` ? "Comprando..." : "Comprar reventa"}
                  </button>
                </div>
              ))}
            </div>
          )}
        </section>
      </div>

      {transferTicket && (
        <Modal title={`Transferir ticket #${transferTicket.id}`} onClose={() => setTransferTicket(null)}>
          <form className="mt-4 flex flex-col gap-3" onSubmit={submitTransfer}>
            <input
              type="text"
              placeholder="Direccion destino 0x..."
              value={transferTo}
              onChange={e => setTransferTo(e.target.value)}
              className="w-full rounded-lg bg-[#ebeef3] px-4 py-3 text-[#131a2b] focus:outline-none focus:ring-2 focus:ring-[#2bb3ec]"
            />
            <button className="rounded-full bg-[#2bb3ec] py-3 font-semibold text-white shadow-md transition hover:bg-[#1ba5dd]">
              Transferir
            </button>
          </form>
        </Modal>
      )}

      {resellTicket && (
        <Modal title={`Poner en reventa #${resellTicket.id}`} onClose={() => setResellTicket(null)}>
          <form className="mt-4 flex flex-col gap-3" onSubmit={submitResell}>
            <input
              type="text"
              placeholder="Precio en ETH"
              value={resellPrice}
              onChange={e => setResellPrice(e.target.value)}
              className="w-full rounded-lg bg-[#ebeef3] px-4 py-3 text-[#131a2b] focus:outline-none focus:ring-2 focus:ring-[#2bb3ec]"
            />
            <button className="rounded-full bg-[#2bb3ec] py-3 font-semibold text-white shadow-md transition hover:bg-[#1ba5dd]">
              Publicar reventa
            </button>
          </form>
        </Modal>
      )}
    </div>
  );
};

const TicketCard = ({
  ticket,
  busy,
  onTransfer,
  onResell,
  onRemoveResell,
  onWithdraw,
}: {
  ticket: TicketView;
  busy: string | null;
  onTransfer: () => void;
  onResell: () => void;
  onRemoveResell: () => void;
  onWithdraw: () => void;
}) => (
  <div className="rounded-2xl bg-white p-6 shadow-md">
    <TicketHeader ticket={ticket} />
    <div className="mt-4 grid grid-cols-2 gap-3 text-sm text-[#131a2b]">
      <Info label="Precio original" value={`${ticket.priceEth} ETH`} />
      <Info label="Propietarios" value={String(ticket.numberOfOwners)} />
      <Info label="Fecha" value={new Date(ticket.eventDate).toLocaleDateString()} />
      <Info label="Estado" value={TICKET_STATE[ticket.state] ?? "-"} />
    </div>

    <div className="mt-5 flex flex-col gap-2">
      {ticket.state === 0 && (
        <>
          <button
            onClick={onResell}
            className="flex w-full cursor-pointer items-center justify-center gap-2 rounded-full bg-[#2bb3ec] py-2.5 text-sm font-semibold text-white shadow-md transition hover:bg-[#1ba5dd]"
          >
            <BanknotesIcon className="h-5 w-5" />
            Revender
          </button>
          <button
            onClick={onTransfer}
            className="flex w-full cursor-pointer items-center justify-center gap-2 rounded-full border border-[#e5e7eb] bg-white py-2.5 text-sm font-semibold text-[#131a2b] transition hover:bg-[#f5f6f8]"
          >
            <ArrowRightIcon className="h-5 w-5" />
            Transferir
          </button>
        </>
      )}
      {ticket.state === 2 && (
        <button
          onClick={onRemoveResell}
          disabled={busy === `remove-${ticket.id}`}
          className="w-full cursor-pointer rounded-full border border-[#e5e7eb] bg-white py-2.5 text-sm font-semibold text-[#131a2b] transition hover:bg-[#f5f6f8] disabled:opacity-60"
        >
          {busy === `remove-${ticket.id}` ? "Quitando..." : "Quitar de reventa"}
        </button>
      )}
      {ticket.state === 4 && (
        <button
          onClick={onWithdraw}
          disabled={busy === `withdraw-${ticket.id}`}
          className="w-full cursor-pointer rounded-full bg-[#2bb3ec] py-2.5 text-sm font-semibold text-white shadow-md transition hover:bg-[#1ba5dd] disabled:opacity-60"
        >
          {busy === `withdraw-${ticket.id}` ? "Retirando..." : "Retirar reembolso"}
        </button>
      )}
    </div>
  </div>
);

const TicketHeader = ({ ticket }: { ticket: TicketView }) => (
  <div className="flex items-start justify-between gap-3">
    <div>
      <h3 className="text-lg font-bold text-[#131a2b]">{ticket.eventName}</h3>
      <p className="mt-1 text-sm text-[#6b7280]">Ticket #{ticket.id}</p>
    </div>
    <span className="rounded-full bg-[#eaf7fd] px-3 py-1 text-xs font-semibold text-[#2bb3ec]">
      {TICKET_STATE[ticket.state] ?? "-"}
    </span>
  </div>
);

const Info = ({ label, value }: { label: string; value: string }) => (
  <div>
    <div className="text-xs text-[#6b7280]">{label}</div>
    <div className="font-semibold">{value}</div>
  </div>
);

const Modal = ({ title, children, onClose }: { title: string; children: React.ReactNode; onClose: () => void }) => (
  <div onClick={onClose} className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4 py-10">
    <div onClick={e => e.stopPropagation()} className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
      <div className="flex items-center justify-between gap-3">
        <h2 className="text-lg font-bold text-[#131a2b]">{title}</h2>
        <button
          onClick={onClose}
          title="Cerrar"
          className="cursor-pointer rounded-full p-1 text-[#6b7280] transition hover:bg-[#f5f6f8] hover:text-[#131a2b]"
        >
          <XMarkIcon className="h-5 w-5" />
        </button>
      </div>
      {children}
    </div>
  </div>
);

export default TicketsPage;
