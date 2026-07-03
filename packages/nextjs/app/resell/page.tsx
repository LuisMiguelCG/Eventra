"use client";

import { useCallback, useEffect, useState } from "react";
import type { NextPage } from "next";
import { ArrowPathIcon, ShoppingBagIcon, TagIcon } from "@heroicons/react/24/outline";
import { formatEther } from "ethers";
import { useWallet } from "~~/hooks/eventra/useWallet";
import { getReadContract, getWriteContract, parseContractError } from "~~/utils/eventra/contract";

type ResellTicket = {
  id: number;
  eventName: string;
  eventDate: number;
  resellPrice: bigint;
  isOwn: boolean;
};

const ResellPage: NextPage = () => {
  const { address, connect } = useWallet();
  const [tickets, setTickets] = useState<ResellTicket[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  const loadTickets = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const readContract = getReadContract();
      const rawIds = await readContract.getTicketsInResell();
      const ids: bigint[] = Array.from(rawIds).map(id => BigInt(String(id)));
      const getEvent = readContract.getFunction("getEvent");

      const settled = await Promise.allSettled(
        ids.map(async id => {
          const ticket = await readContract.tickets(id);
          // Use positional access (reliable across all ethers v6 Result shapes)
          const eventId = BigInt(String(ticket[0]));
          const ticketUser = String(ticket[1]);
          const ev = await getEvent(eventId);
          const rawPrice = await readContract.ticketResellPrice(id);
          const resellPrice = BigInt(String(rawPrice));
          return {
            id: Number(id),
            eventName: String(ev.eventName),
            eventDate: Number(ev.eventDate) * 1000,
            resellPrice,
            isOwn: address ? ticketUser.toLowerCase() === address.toLowerCase() : false,
          };
        }),
      );

      const result: ResellTicket[] = settled
        .filter((s): s is PromiseFulfilledResult<ResellTicket> => s.status === "fulfilled")
        .map(s => s.value)
        .sort((a, b) => b.id - a.id);

      setTickets(result);
    } catch (e: any) {
      setError(parseContractError(e));
      setTickets([]);
    } finally {
      setLoading(false);
    }
  }, [address]);

  useEffect(() => {
    loadTickets();
  }, [loadTickets]);

  const handleBuy = async (ticket: ResellTicket) => {
    setError(null);
    setBusy(ticket.id);
    try {
      const signer = await connect();
      const tx = await getWriteContract(signer).buyTicketFromResell(ticket.id, { value: ticket.resellPrice });
      await tx.wait();
      await loadTickets();
    } catch (e: any) {
      setError(parseContractError(e));
    } finally {
      setBusy(null);
    }
  };

  return (
    <div className="mx-auto max-w-4xl px-4 py-10">
      <div className="mb-6 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <TagIcon className="h-7 w-7 text-[#2bb3ec]" />
          <h1 className="text-2xl font-bold text-[#131a2b]">Reventa</h1>
        </div>
        <button
          onClick={loadTickets}
          disabled={loading}
          className="inline-flex cursor-pointer items-center gap-2 rounded-full border border-[#e5e7eb] bg-white px-4 py-2 text-sm font-semibold text-[#131a2b] transition hover:bg-[#f5f6f8] disabled:opacity-60"
        >
          <ArrowPathIcon className={`h-4 w-4 ${loading ? "animate-spin" : ""}`} />
          Actualizar
        </button>
      </div>

      {error && <div className="mb-4 rounded-lg bg-[#fdecec] px-3 py-2 text-sm text-[#b42424]">{error}</div>}
      {loading && <p className="text-sm text-[#6b7280]">Cargando tickets en reventa...</p>}

      {tickets && tickets.length === 0 && !loading && (
        <div className="rounded-2xl bg-white p-10 text-center shadow-md">
          <TagIcon className="mx-auto h-10 w-10 text-[#2bb3ec] opacity-30" strokeWidth={1.5} />
          <p className="mt-3 text-sm text-[#6b7280]">No hay tickets en reventa ahora mismo.</p>
        </div>
      )}

      {tickets && tickets.length > 0 && (
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          {tickets.map(ticket => (
            <div key={ticket.id} className="rounded-2xl bg-white p-6 shadow-md">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <h3 className="text-lg font-bold text-[#131a2b]">{ticket.eventName}</h3>
                  <p className="mt-1 text-sm text-[#6b7280]">Ticket #{ticket.id}</p>
                </div>
                <span className="shrink-0 rounded-full bg-[#eaf7fd] px-3 py-1 text-xs font-semibold text-[#2bb3ec]">
                  En reventa
                </span>
              </div>

              <div className="mt-4 grid grid-cols-2 gap-3 text-sm text-[#131a2b]">
                <div>
                  <div className="text-xs text-[#6b7280]">Precio</div>
                  <div className="font-semibold">{formatEther(ticket.resellPrice)} ETH</div>
                </div>
                <div>
                  <div className="text-xs text-[#6b7280]">Fecha del evento</div>
                  <div className="font-semibold">{new Date(ticket.eventDate).toLocaleDateString()}</div>
                </div>
              </div>

              {ticket.isOwn ? (
                <p className="mt-5 text-center text-sm text-[#6b7280]">Este ticket es tuyo</p>
              ) : (
                <button
                  onClick={() => handleBuy(ticket)}
                  disabled={busy === ticket.id}
                  className="mt-5 flex w-full cursor-pointer items-center justify-center gap-2 rounded-full bg-[#2bb3ec] py-3 text-sm font-semibold text-white shadow-md transition hover:bg-[#1ba5dd] disabled:opacity-60"
                >
                  <ShoppingBagIcon className="h-5 w-5" />
                  {busy === ticket.id ? "Comprando..." : "Comprar"}
                </button>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default ResellPage;
