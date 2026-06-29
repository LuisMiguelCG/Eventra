"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Bars3Icon, TicketIcon } from "@heroicons/react/24/outline";

type HeaderMenuLink = {
  label: string;
  href: string;
};

export const menuLinks: HeaderMenuLink[] = [
  { label: "Inicio", href: "/" },
  { label: "Eventos", href: "/events" },
  { label: "Mis tickets", href: "/tickets" },
  { label: "Crear cuenta", href: "/register" },
];

export const HeaderMenuLinks = () => {
  const pathname = usePathname();

  return (
    <>
      {menuLinks.map(({ label, href }) => {
        const isActive = pathname === href;
        return (
          <li key={href}>
            <Link
              href={href}
              className={`${
                isActive ? "text-[#2bb3ec]" : "text-[#131a2b]"
              } block rounded-lg px-3 py-1.5 text-sm font-medium hover:text-[#2bb3ec]`}
            >
              {label}
            </Link>
          </li>
        );
      })}
    </>
  );
};

export const Header = () => {
  return (
    <header className="sticky top-0 z-20 flex items-center justify-between border-b border-[#eef0f3] bg-white px-4 py-2 shadow-sm lg:static">
      <div className="flex items-center gap-6">
        <Link href="/" className="flex shrink-0 items-center gap-2">
          <TicketIcon className="h-7 w-7 text-[#2bb3ec]" />
          <span className="text-lg font-bold text-[#131a2b]">Eventra</span>
        </Link>
        <ul className="hidden items-center gap-1 lg:flex">
          <HeaderMenuLinks />
        </ul>
      </div>

      <details className="relative lg:hidden">
        <summary className="flex cursor-pointer list-none items-center rounded-lg p-2 hover:bg-[#f5f6f8]">
          <Bars3Icon className="h-5 w-5 text-[#131a2b]" />
        </summary>
        <ul className="absolute right-0 mt-2 w-52 rounded-xl border border-[#eef0f3] bg-white p-2 shadow-md">
          <HeaderMenuLinks />
        </ul>
      </details>
    </header>
  );
};
