"use client";

import Link from "next/link";
import type { NextPage } from "next";
import {
  ArrowRightStartOnRectangleIcon,
  PlusIcon,
  ShoppingBagIcon,
  TicketIcon,
  UserCircleIcon,
} from "@heroicons/react/24/outline";
import { useWallet } from "~~/hooks/eventra/useWallet";

const short = (a: string) => `${a.slice(0, 6)}…${a.slice(-4)}`;

const Home: NextPage = () => {
  const { address, connect, disconnect } = useWallet();

  return (
    <div className="flex grow flex-col items-center justify-center bg-[#f5f6f8] px-4 py-16">
      <div className="flex flex-col items-center text-center">
        <div className="flex items-center gap-3">
          <TicketIcon className="h-10 w-10 text-[#2bb3ec]" />
          <h1 className="text-4xl font-bold text-[#131a2b]">Eventra</h1>
        </div>
        <p className="mt-3 max-w-md text-[#6b7280]">
          Crea eventos, descubre experiencias y compra entradas. La plataforma para tu comunidad.
        </p>
      </div>

      <div className="mt-10 w-full max-w-md">
        {address ? (
          <div className="rounded-2xl bg-white p-6 shadow-md">
            <div className="flex items-center gap-3">
              <UserCircleIcon className="h-7 w-7 text-[#2bb3ec]" />
              <div>
                <div className="font-bold text-[#131a2b]">Wallet conectada</div>
                <div className="break-all font-mono text-sm text-[#6b7280]">{short(address)}</div>
              </div>
            </div>

            <Link
              href="/events"
              className="mt-5 flex w-full items-center justify-center gap-2 rounded-full bg-[#2bb3ec] py-3 font-semibold text-white shadow-md transition hover:bg-[#1ba5dd]"
            >
              <ShoppingBagIcon className="h-5 w-5" />
              Comprar entradas
            </Link>
            <Link
              href="/tickets"
              className="mt-3 flex w-full items-center justify-center gap-2 rounded-full border border-[#e5e7eb] bg-white py-3 font-semibold text-[#131a2b] transition hover:bg-[#f5f6f8]"
            >
              <TicketIcon className="h-5 w-5" />
              Mis tickets
            </Link>
            <Link
              href="/events/create"
              className="mt-3 flex w-full items-center justify-center gap-2 rounded-full border border-[#e5e7eb] bg-white py-3 font-semibold text-[#131a2b] transition hover:bg-[#f5f6f8]"
            >
              <PlusIcon className="h-5 w-5" />
              Crear evento
            </Link>
            <Link
              href="/events/mine"
              className="mt-3 flex w-full items-center justify-center rounded-full border border-[#e5e7eb] bg-white py-3 font-semibold text-[#131a2b] transition hover:bg-[#f5f6f8]"
            >
              Mis eventos
            </Link>
            <button
              onClick={disconnect}
              className="mt-3 flex w-full cursor-pointer items-center justify-center gap-2 rounded-full border border-[#e5e7eb] bg-white py-3 font-semibold text-[#b42424] transition hover:bg-[#fdecec]"
            >
              <ArrowRightStartOnRectangleIcon className="h-5 w-5" />
              Desconectar
            </button>
          </div>
        ) : (
          <div className="flex flex-col gap-3">
            <button
              onClick={connect}
              className="w-full cursor-pointer rounded-full bg-[#2bb3ec] py-3 text-center font-semibold text-white shadow-md transition hover:bg-[#1ba5dd]"
            >
              Conectar wallet
            </button>
            <Link
              href="/events"
              className="w-full cursor-pointer rounded-full border border-[#2bb3ec] bg-white py-3 text-center font-semibold text-[#2bb3ec] transition hover:bg-[#eaf7fd]"
            >
              Ver eventos
            </Link>
            <Link
              href="/register"
              className="w-full cursor-pointer rounded-full border border-[#e5e7eb] bg-white py-3 text-center font-semibold text-[#131a2b] transition hover:bg-[#f5f6f8]"
            >
              Crear cuenta
            </Link>
          </div>
        )}
      </div>
    </div>
  );
};

export default Home;
