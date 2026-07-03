"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { formatEther } from "ethers";
import type { NextPage } from "next";
import { ArrowPathIcon, CalendarDaysIcon, ShoppingBagIcon, TicketIcon } from "@heroicons/react/24/outline";
import { useWallet } from "~~/hooks/eventra/useWallet";
import { getReadContract, getWriteContract, parseContractError } from "~~/utils/eventra/contract";

type EventView = {
  id: number;
  name: string;
  description: string;
  priceEth: string;
  priceWei: bigint;
  eventDate: number;
  startSellDate: number;
  endSellDate: number;
  ticketsSold: number;
  totalTickets: number;
  maxPerAddress: number;
  organizer: string;
  state: number;
};

const isOnSale = (ev: EventView) =>
  ev.state === 0 && Date.now() >= ev.startSellDate && Date.now() <= ev.endSellDate && ev.ticketsSold < ev.totalTickets;

const Home: NextPage = () => {
  const { address, connect } = useWallet();
  const [events, setEvents] = useState<EventView[] | null>(null);
  const [ownerCommission, setOwnerCommission] = useState<bigint>(0n);
  const [loading, setLoading] = useState(false);
  const [buying, setBuying] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  const loadEvents = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const contract = getReadContract();
      const ids: bigint[] = await contract.getAllEvents();
      const [all, commission] = await Promise.all([
        Promise.all(ids.map(id => contract.getFunction("getEvent")(id))),
        contract.OWNER_COMMISSION(),
      ]);

      setOwnerCommission(commission);
      setEvents(
        all
          .map(ev => ({
            id: Number(ev.eventId),
            name: ev.eventName,
            description: ev.eventDescription,
            priceEth: formatEther(ev.ticketPrice),
            priceWei: ev.ticketPrice as bigint,
            eventDate: Number(ev.eventDate) * 1000,
            startSellDate: Number(ev.startSellDate) * 1000,
            endSellDate: Number(ev.endSellDate) * 1000,
            ticketsSold: Number(ev.ticketsSold),
            totalTickets: Number(ev.totalTicketNumber),
            maxPerAddress: Number(ev.maxTicketsPerAddress),
            organizer: ev.organizer,
            state: Number(ev.eventState),
          }))
          .sort((a, b) => a.eventDate - b.eventDate),
      );
    } catch (e) {
      setError(parseContractError(e));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadEvents();
  }, [loadEvents]);

  const handleBuy = async (ev: EventView) => {
    setError(null);
    setBuying(ev.id);
    try {
      const signer = await connect();
      const contract = getWriteContract(signer);
      const total = ev.priceWei + (ev.priceWei * ownerCommission) / 100n;
      const tx = await contract.buyTicket(ev.id, { value: total });
      await tx.wait();
      await loadEvents();
    } catch (e) {
      setError(parseContractError(e));
    } finally {
      setBuying(null);
    }
  };

  const activeEvents = useMemo(() => events?.filter(ev => ev.state !== 3 && ev.state !== 4) ?? [], [events]);

  return (
    <div className="mx-auto w-full max-w-4xl px-4 py-10">
      <div className="mb-6 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <TicketIcon className="h-7 w-7 text-[#2bb3ec]" />
          <h1 className="text-2xl font-bold text-[#131a2b]">Eventos disponibles</h1>
        </div>
        <button
          onClick={loadEvents}
          disabled={loading}
          className="inline-flex cursor-pointer items-center gap-2 rounded-full border border-[#e5e7eb] bg-white px-4 py-2 text-sm font-semibold text-[#131a2b] transition hover:bg-[#f5f6f8] disabled:opacity-60"
        >
          <ArrowPathIcon className={`h-4 w-4 ${loading ? "animate-spin" : ""}`} />
          Actualizar
        </button>
      </div>

      {error && <div className="mb-4 rounded-lg bg-[#fdecec] px-3 py-2 text-sm text-[#b42424]">{error}</div>}
      {loading && <p className="text-center text-sm text-[#6b7280]">Cargando eventos...</p>}

      {events && activeEvents.length === 0 && !loading && (
        <div className="rounded-2xl bg-white p-10 text-center shadow-md">
          <CalendarDaysIcon className="mx-auto h-12 w-12 text-[#cbd1d9]" strokeWidth={1.5} />
          <h2 className="mt-3 text-lg font-bold text-[#131a2b]">No hay eventos publicados</h2>
          <p className="mt-1 text-sm text-[#6b7280]">Cuando una empresa cree eventos, aparecerán aquí.</p>
        </div>
      )}

      {activeEvents.length > 0 && (
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          {activeEvents.map(ev => {
            const total = ev.priceWei + (ev.priceWei * ownerCommission) / 100n;
            const canBuy = address && isOnSale(ev) && ev.organizer.toLowerCase() !== address.toLowerCase();

            return (
              <div key={ev.id} className="rounded-2xl bg-white p-6 shadow-md">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <h2 className="text-lg font-bold text-[#131a2b]">{ev.name}</h2>
                    <p className="mt-1 text-sm text-[#6b7280]">{ev.description}</p>
                  </div>
                  <span className="shrink-0 rounded-full bg-[#eaf7fd] px-3 py-1 text-xs font-semibold text-[#2bb3ec]">
                    {ev.state === 2 ? "Agotado" : isOnSale(ev) ? "En venta" : "Próximamente"}
                  </span>
                </div>

                <div className="mt-5 grid grid-cols-2 gap-3 text-sm text-[#131a2b]">
                  <Info label="Fecha" value={new Date(ev.eventDate).toLocaleDateString()} />
                  <Info label="Precio" value={`${ev.priceEth} ETH`} />
                  <Info label="Comisión" value={`${ownerCommission.toString()}%`} />
                  <Info label="Total pago" value={`${formatEther(total)} ETH`} />
                  <Info label="Vendidas" value={`${ev.ticketsSold} / ${ev.totalTickets}`} />
                  <Info label="Máx. por wallet" value={String(ev.maxPerAddress)} />
                </div>

                <div className="mt-4 rounded-xl bg-[#f5f6f8] p-3 text-xs text-[#6b7280]">
                  Venta: {new Date(ev.startSellDate).toLocaleString()} – {new Date(ev.endSellDate).toLocaleString()}
                </div>

                <button
                  onClick={() => handleBuy(ev)}
                  disabled={!canBuy || buying === ev.id}
                  className="mt-5 flex w-full cursor-pointer items-center justify-center gap-2 rounded-full bg-[#2bb3ec] py-3 text-sm font-semibold text-white shadow-md transition hover:bg-[#1ba5dd] disabled:cursor-not-allowed disabled:opacity-60"
                >
                  <ShoppingBagIcon className="h-5 w-5" />
                  {buying === ev.id ? "Comprando..." : address ? "Comprar entrada" : "Conecta wallet para comprar"}
                </button>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

const Info = ({ label, value }: { label: string; value: string }) => (
  <div>
    <div className="text-xs text-[#6b7280]">{label}</div>
    <div className="font-semibold">{value}</div>
  </div>
);

export default Home;
