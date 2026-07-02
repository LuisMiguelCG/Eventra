"use client";

import { useCallback, useEffect, useState } from "react";
import type { NextPage } from "next";
import { ArrowPathIcon, BanknotesIcon } from "@heroicons/react/24/outline";
import { ethers } from "ethers";
import { getRoleKey } from "~~/components/Header";
import { useWallet } from "~~/hooks/eventra/useWallet";
import { getReadContract, getWriteContract, parseContractError } from "~~/utils/eventra/contract";

type Role = "user" | "company" | null;

const TicketCanceled = 4;
const EventCanceled = 3;
const EventFinished = 4;
const ONE_DAY = 86400n;

type CancelledTicket = { ticketId: bigint; eventName: string; amount: bigint };
type CompanyEvent = { eventId: bigint; eventName: string; balance: bigint; canWithdraw: boolean; state: number };

const fmt = (wei: bigint) => `${ethers.formatEther(wei)} ETH`;

const FundsPage: NextPage = () => {
  const { address, connect } = useWallet();
  const [role, setRole] = useState<Role>(null);
  const [isOwner, setIsOwner] = useState(false);
  const [loading, setLoading] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [txError, setTxError] = useState<string | null>(null);

  // User state
  const [pendingTotal, setPendingTotal] = useState<bigint | null>(null);
  const [cancelledTickets, setCancelledTickets] = useState<CancelledTicket[]>([]);
  const [withdrawingTicket, setWithdrawingTicket] = useState<bigint | null>(null);

  // Company state
  const [companyEvents, setCompanyEvents] = useState<CompanyEvent[]>([]);
  const [withdrawingEvent, setWithdrawingEvent] = useState<bigint | null>(null);

  // Owner state
  const [ownerBalance, setOwnerBalance] = useState<bigint | null>(null);
  const [withdrawingOwner, setWithdrawingOwner] = useState(false);

  useEffect(() => {
    if (!address) {
      setRole(null);
      setIsOwner(false);
      return;
    }
    const saved = localStorage.getItem(getRoleKey(address)) as Role;
    setRole(saved);

    const readContract = getReadContract();
    readContract.owner().then((ownerAddr: unknown) => {
      setIsOwner(String(ownerAddr).toLowerCase() === address.toLowerCase());
    }).catch(() => {});
  }, [address]);

  const loadUserFunds = useCallback(async () => {
    if (!address) return;
    setLoading(true);
    setLoadError(null);
    try {
      const readContract = getReadContract();
      const total = BigInt(String(await readContract.pendingRefunds(address)));
      setPendingTotal(total);

      if (total > 0n) {
        const signer = await connect();
        const writeContract = getWriteContract(signer);
        const ticketIds: bigint[] = Array.from(await writeContract.getAllUserTickets()).map(id => BigInt(String(id)));
        const getEventFn = readContract.getFunction("getEvent");

        const cancelled: CancelledTicket[] = [];
        for (const ticketId of ticketIds) {
          const ticket = await writeContract.getTicket(ticketId);
          if (Number(ticket.ticketState) === TicketCanceled) {
            const ev = await getEventFn(ticket.eventId);
            cancelled.push({ ticketId, eventName: String(ev.eventName), amount: ev.ticketPrice as bigint });
          }
        }
        setCancelledTickets(cancelled);
      }
    } catch {
      setLoadError("Error al cargar los fondos. Comprueba que la blockchain está activa.");
    } finally {
      setLoading(false);
    }
  }, [address, connect]);

  const loadCompanyFunds = useCallback(async () => {
    if (!address) return;
    setLoading(true);
    setLoadError(null);
    try {
      const readContract = getReadContract();
      const rawEventIds = await readContract.getAllEvents();
      const eventIds: bigint[] = Array.from(rawEventIds).map(id => BigInt(String(id)));
      const now = BigInt(Math.floor(Date.now() / 1000));
      const getEventFn = readContract.getFunction("getEvent");

      const result: CompanyEvent[] = [];
      for (const eventId of eventIds) {
        const ev = await getEventFn(eventId);
        if (String(ev.organizer).toLowerCase() !== address.toLowerCase()) continue;

        const balance = BigInt(String(await readContract.eventBalance(eventId)));
        const state = Number(ev.eventState);
        const canWithdraw =
          state !== EventCanceled &&
          state !== EventFinished &&
          now >= BigInt(String(ev.eventDate)) + ONE_DAY;

        result.push({ eventId, eventName: String(ev.eventName), balance, canWithdraw, state });
      }
      setCompanyEvents(result);
    } catch {
      setLoadError("Error al cargar los fondos. Comprueba que la blockchain está activa.");
    } finally {
      setLoading(false);
    }
  }, [address]);

  const loadOwnerFunds = useCallback(async () => {
    setLoading(true);
    setLoadError(null);
    try {
      const balance = BigInt(String(await getReadContract().ownerBalance()));
      setOwnerBalance(balance);
    } catch {
      setLoadError("Error al cargar los fondos. Comprueba que la blockchain está activa.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!address) return;
    if (isOwner) loadOwnerFunds();
    else if (role === "user") loadUserFunds();
    else if (role === "company") loadCompanyFunds();
  }, [address, role, isOwner, loadUserFunds, loadCompanyFunds, loadOwnerFunds]);

  const handleWithdrawTicket = async (ticketId: bigint) => {
    setTxError(null);
    setWithdrawingTicket(ticketId);
    try {
      const signer = await connect();
      const tx = await getWriteContract(signer).withdrawUserFunds(ticketId);
      await tx.wait();
      setCancelledTickets(prev => prev.filter(t => t.ticketId !== ticketId));
      setPendingTotal(BigInt(String(await getReadContract().pendingRefunds(address!))));
    } catch (err: any) {
      setTxError(parseContractError(err));
    } finally {
      setWithdrawingTicket(null);
    }
  };

  const handleWithdrawEvent = async (eventId: bigint) => {
    setTxError(null);
    setWithdrawingEvent(eventId);
    try {
      const signer = await connect();
      const tx = await getWriteContract(signer).withdrawCompanyFunds(eventId);
      await tx.wait();
      setCompanyEvents(prev =>
        prev.map(e =>
          e.eventId === eventId ? { ...e, balance: 0n, canWithdraw: false, state: EventFinished } : e,
        ),
      );
    } catch (err: any) {
      setTxError(parseContractError(err));
    } finally {
      setWithdrawingEvent(null);
    }
  };

  const handleWithdrawOwner = async () => {
    setTxError(null);
    setWithdrawingOwner(true);
    try {
      const signer = await connect();
      const tx = await getWriteContract(signer).withdrawOwnerFunds();
      await tx.wait();
      setOwnerBalance(0n);
    } catch (err: any) {
      setTxError(parseContractError(err));
    } finally {
      setWithdrawingOwner(false);
    }
  };

  if (!address) {
    return (
      <div className="flex grow items-center justify-center bg-[#f5f6f8] px-4 py-10">
        <div className="text-center text-[#6b7280]">
          <BanknotesIcon className="mx-auto mb-3 h-12 w-12 opacity-40" />
          <p>Conecta tu wallet para ver tus fondos.</p>
        </div>
      </div>
    );
  }

  if (!role && !isOwner) {
    return (
      <div className="flex grow items-center justify-center bg-[#f5f6f8] px-4 py-10">
        <div className="text-center text-[#6b7280]">
          <BanknotesIcon className="mx-auto mb-3 h-12 w-12 opacity-40" />
          <p>No tienes una cuenta registrada en Eventra.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-2xl px-4 py-10">
      <div className="mb-6 flex items-center gap-3">
        <BanknotesIcon className="h-7 w-7 text-[#2bb3ec]" />
        <h1 className="text-2xl font-bold text-[#131a2b]">Mis fondos</h1>
      </div>

      {loadError && <div className="mb-4 rounded-lg bg-[#fdecec] px-4 py-3 text-sm text-[#b42424]">{loadError}</div>}
      {txError && <div className="mb-4 rounded-lg bg-[#fdecec] px-4 py-3 text-sm text-[#b42424]">{txError}</div>}

      {loading && (
        <div className="flex items-center gap-2 text-sm text-[#6b7280]">
          <ArrowPathIcon className="h-4 w-4 animate-spin" />
          Cargando fondos...
        </div>
      )}

      {/* ── Owner ────────────────────────────────────── */}
      {isOwner && !loading && (
        <div className="flex items-center justify-between rounded-2xl bg-white p-5 shadow-sm">
          <div>
            <div className="text-sm text-[#6b7280]">Comisiones acumuladas</div>
            <div className="mt-1 text-3xl font-bold text-[#131a2b]">
              {ownerBalance !== null ? fmt(ownerBalance) : "—"}
            </div>
          </div>
          {ownerBalance !== null && ownerBalance > 0n && (
            <button
              onClick={handleWithdrawOwner}
              disabled={withdrawingOwner}
              className="cursor-pointer rounded-full bg-[#2bb3ec] px-4 py-2 text-sm font-semibold text-white transition hover:bg-[#1ba5dd] disabled:opacity-60"
            >
              {withdrawingOwner ? "Retirando..." : "Retirar"}
            </button>
          )}
        </div>
      )}

      {/* ── Usuario ─────────────────────────────────── */}
      {role === "user" && !isOwner && !loading && (
        <>
          <div className="mb-5 rounded-2xl bg-white p-5 shadow-sm">
            <div className="text-sm text-[#6b7280]">Total pendiente de reembolso</div>
            <div className="mt-1 text-3xl font-bold text-[#131a2b]">
              {pendingTotal !== null ? fmt(pendingTotal) : "—"}
            </div>
          </div>

          {cancelledTickets.length === 0 && pendingTotal === 0n && (
            <p className="text-sm text-[#6b7280]">No tienes fondos pendientes de reembolso.</p>
          )}

          {cancelledTickets.length > 0 && (
            <div className="flex flex-col gap-3">
              <h2 className="font-semibold text-[#131a2b]">Tickets cancelados</h2>
              {cancelledTickets.map(t => (
                <div
                  key={t.ticketId.toString()}
                  className="flex items-center justify-between rounded-2xl bg-white p-4 shadow-sm"
                >
                  <div>
                    <div className="font-medium text-[#131a2b]">{t.eventName}</div>
                    <div className="text-sm text-[#6b7280]">
                      Ticket #{t.ticketId.toString()} · {fmt(t.amount)}
                    </div>
                  </div>
                  <button
                    onClick={() => handleWithdrawTicket(t.ticketId)}
                    disabled={withdrawingTicket === t.ticketId}
                    className="cursor-pointer rounded-full bg-[#2bb3ec] px-4 py-2 text-sm font-semibold text-white transition hover:bg-[#1ba5dd] disabled:opacity-60"
                  >
                    {withdrawingTicket === t.ticketId ? "Retirando..." : "Retirar"}
                  </button>
                </div>
              ))}
            </div>
          )}
        </>
      )}

      {/* ── Empresa ─────────────────────────────────── */}
      {role === "company" && !isOwner && !loading && (
        <>
          {companyEvents.length === 0 ? (
            <p className="text-sm text-[#6b7280]">No tienes eventos creados como empresa.</p>
          ) : (
            <div className="flex flex-col gap-3">
              <h2 className="font-semibold text-[#131a2b]">Fondos por evento</h2>
              {companyEvents.map(e => (
                <div
                  key={e.eventId.toString()}
                  className="flex items-center justify-between rounded-2xl bg-white p-4 shadow-sm"
                >
                  <div>
                    <div className="font-medium text-[#131a2b]">{e.eventName}</div>
                    <div className="text-sm text-[#6b7280]">
                      {fmt(e.balance)}
                      {e.state === EventFinished && " · Retirado"}
                      {e.state === EventCanceled && " · Evento cancelado"}
                      {e.state !== EventFinished && e.state !== EventCanceled && !e.canWithdraw && (
                        <> · Disponible tras el evento</>
                      )}
                    </div>
                  </div>
                  {e.canWithdraw && e.balance > 0n ? (
                    <button
                      onClick={() => handleWithdrawEvent(e.eventId)}
                      disabled={withdrawingEvent === e.eventId}
                      className="cursor-pointer rounded-full bg-[#2bb3ec] px-4 py-2 text-sm font-semibold text-white transition hover:bg-[#1ba5dd] disabled:opacity-60"
                    >
                      {withdrawingEvent === e.eventId ? "Retirando..." : "Retirar"}
                    </button>
                  ) : e.state === EventFinished ? (
                    <span className="rounded-full bg-[#e8f8f0] px-3 py-1 text-sm font-medium text-[#16a34a]">
                      Retirado
                    </span>
                  ) : null}
                </div>
              ))}
            </div>
          )}
        </>
      )}
    </div>
  );
};

export default FundsPage;
