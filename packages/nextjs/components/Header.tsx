"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { FormEvent, useEffect, useRef, useState } from "react";
import {
  BuildingOffice2Icon,
  ChevronDownIcon,
  PlusIcon,
  TicketIcon,
  UserCircleIcon,
  XMarkIcon,
} from "@heroicons/react/24/outline";
import { useWallet } from "~~/hooks/eventra/useWallet";
import { getReadContract, getWriteContract, parseContractError } from "~~/utils/eventra/contract";

type HeaderMenuLink = { label: string; href: string };

const short = (a: string) => `${a.slice(0, 6)}…${a.slice(-4)}`;

type Role = "user" | "company" | null;
type RegisterResult = { address: string; company: boolean; name: string | null };

export const getRoleKey = (addr: string) => `eventra:role:${addr.toLowerCase()}`;

const HeaderMenuLinks = ({ links }: { links: HeaderMenuLink[] }) => {
  const pathname = usePathname();
  return (
    <>
      {links.map(({ label, href }) => {
        const isActive = pathname === href;
        return (
          <li key={href}>
            <Link
              href={href}
              className={`${isActive ? "text-[#2bb3ec]" : "text-[#131a2b]"} block rounded-lg px-3 py-1.5 text-sm font-medium hover:text-[#2bb3ec]`}
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
  const { address, connect, disconnect } = useWallet();
  const [role, setRole] = useState<Role>(null);
  const [isOwner, setIsOwner] = useState(false);
  const [roleLoading, setRoleLoading] = useState(false);
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  const [modalOpen, setModalOpen] = useState(false);
  const [asCompany, setAsCompany] = useState(true);
  const [companyName, setCompanyName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [result, setResult] = useState<RegisterResult | null>(null);
  const [registeringAddress, setRegisteringAddress] = useState<string | null>(null);

  useEffect(() => {
    if (!address) {
      setRole(null);
      setRoleLoading(false);
      return;
    }

    // Clear stale role from previous wallet immediately
    setRole(null);
    setIsOwner(false);
    setDropdownOpen(false);

    // Restore from per-address localStorage for instant feedback
    const key = getRoleKey(address);
    const saved = localStorage.getItem(key) as Role;
    if (saved) {
      setRole(saved);
    } else {
      setRoleLoading(true);
    }

    // Verify against the contract (source of truth)
    const contract = getReadContract();
    Promise.all([contract.companies(address), contract.users(address), contract.owner()])
      .then(([isCompany, isUser, ownerAddr]) => {
        const owner = String(ownerAddr).toLowerCase() === address.toLowerCase();
        setIsOwner(owner);
        const detected: Role = isCompany ? "company" : isUser ? "user" : null;
        setRole(detected);
        if (detected) localStorage.setItem(key, detected);
        else localStorage.removeItem(key);
      })
      .catch(() => {
        // Keep localStorage value on RPC failure
      })
      .finally(() => setRoleLoading(false));
  }, [address]);

  useEffect(() => {
    if (!dropdownOpen) return;
    const handle = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setDropdownOpen(false);
      }
    };
    document.addEventListener("mousedown", handle);
    return () => document.removeEventListener("mousedown", handle);
  }, [dropdownOpen]);

  const openModal = async () => {
    setAsCompany(true);
    setCompanyName("");
    setError(null);
    setResult(null);
    setRegisteringAddress(null);
    setModalOpen(true);

    // If already connected via useWallet, use that address directly
    if (address) {
      setRegisteringAddress(address);
      return;
    }

    // Otherwise silently read connected accounts (no MetaMask popup)
    try {
      const eth = (window as any).ethereum;
      if (eth) {
        const accounts: string[] = await eth.request({ method: "eth_accounts" });
        if (accounts.length > 0) setRegisteringAddress(accounts[0]);
      }
    } catch {
      // ignore — user can connect manually
    }
  };

  const handleDetectWallet = async () => {
    try {
      const eth = (window as any).ethereum;
      if (!eth) { setError("Instala MetaMask para continuar."); return; }
      const accounts: string[] = await eth.request({ method: "eth_requestAccounts" });
      if (accounts.length > 0) setRegisteringAddress(accounts[0]);
    } catch {
      setError("No se pudo conectar la wallet.");
    }
  };

  const closeModal = () => {
    setModalOpen(false);
    setResult(null);
    setError(null);
    setSubmitting(false);
    setRegisteringAddress(null);
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    if (asCompany && !companyName.trim()) {
      setError("Introduce el nombre de la empresa.");
      return;
    }
    setSubmitting(true);
    try {
      const signer = await connect();
      const addr = await signer.getAddress();
      setRegisteringAddress(addr);
      const contract = getWriteContract(signer);
      const tx = asCompany
        ? await contract.registerCompany(companyName.trim(), addr)
        : await contract.registerUser();
      await tx.wait();
      const newRole: Role = asCompany ? "company" : "user";
      setResult({ address: addr, company: asCompany, name: asCompany ? companyName.trim() : null });
      setRole(newRole);
      localStorage.setItem(getRoleKey(addr), newRole);
    } catch (err: any) {
      setError(parseContractError(err));
    } finally {
      setSubmitting(false);
    }
  };

  const handleDisconnect = () => {
    if (address) localStorage.removeItem(getRoleKey(address));
    disconnect();
    setDropdownOpen(false);
    setRole(null);
    setIsOwner(false);
  };

  const navLinks: HeaderMenuLink[] = isOwner
    ? [{ label: "Inicio", href: "/" }, { label: "Mis fondos", href: "/funds" }]
    : role === "user"
      ? [{ label: "Inicio", href: "/" }, { label: "Mis tickets", href: "/tickets" }, { label: "Reventa", href: "/resell" }]
      : role === "company"
        ? [{ label: "Inicio", href: "/" }, { label: "Mis eventos", href: "/events/mine" }, { label: "Mis fondos", href: "/funds" }, { label: "Crear evento", href: "/events/create" }]
        : [{ label: "Inicio", href: "/" }];

  return (
    <>
      <header className="sticky top-0 z-20 flex items-center justify-between border-b border-[#eef0f3] bg-white px-4 py-2 shadow-sm lg:static">
        <div className="flex items-center gap-6">
          <Link href="/" className="flex shrink-0 items-center gap-2">
            <TicketIcon className="h-7 w-7 text-[#2bb3ec]" />
            <span className="text-lg font-bold text-[#131a2b]">Eventra</span>
          </Link>
          <ul className="flex items-center gap-1">
            <HeaderMenuLinks links={navLinks} />
          </ul>
        </div>

        {address && (role || isOwner) ? (
          <div className="relative" ref={dropdownRef}>
            <button
              onClick={() => setDropdownOpen(o => !o)}
              className="flex cursor-pointer items-center gap-1.5 rounded-full bg-[#2bb3ec] px-4 py-2 font-mono text-sm font-semibold text-white shadow-md transition hover:bg-[#1ba5dd]"
            >
              <UserCircleIcon className="h-4 w-4 shrink-0" />
              {short(address)}
              <ChevronDownIcon className={`h-4 w-4 transition-transform ${dropdownOpen ? "rotate-180" : ""}`} />
            </button>

            {dropdownOpen && (
              <div className="absolute right-0 mt-2 w-40 rounded-xl border border-[#eef0f3] bg-white p-1.5 shadow-md">
                <button
                  onClick={handleDisconnect}
                  className="w-full cursor-pointer rounded-lg px-3 py-2 text-left text-sm text-[#b42424] hover:bg-[#fdecec]"
                >
                  Desconectar
                </button>
              </div>
            )}
          </div>
        ) : address && roleLoading ? (
          <span className="flex items-center gap-1.5 rounded-full border border-[#eef0f3] bg-[#f5f6f8] px-4 py-2 font-mono text-sm text-[#6b7280]">
            <UserCircleIcon className="h-4 w-4 shrink-0" />
            {short(address)}
          </span>
        ) : (
          <button
            onClick={openModal}
            className="cursor-pointer rounded-full bg-[#2bb3ec] px-4 py-2 text-sm font-semibold text-white shadow-md transition hover:bg-[#1ba5dd]"
          >
            Crear cuenta
          </button>
        )}
      </header>

      {modalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-xl font-bold text-[#131a2b]">{result ? "Registro completado" : "Crea tu cuenta"}</h2>
              <button onClick={closeModal} className="cursor-pointer rounded-lg p-1 hover:bg-[#f5f6f8]">
                <XMarkIcon className="h-5 w-5 text-[#131a2b]" />
              </button>
            </div>

            {result ? (
              <>
                <div className="flex items-center gap-3">
                  {result.company ? (
                    <BuildingOffice2Icon className="h-7 w-7 text-[#2bb3ec]" />
                  ) : (
                    <UserCircleIcon className="h-7 w-7 text-[#2bb3ec]" />
                  )}
                  <div>
                    <div className="font-bold text-[#131a2b]">Wallet conectada</div>
                    <div className="break-all font-mono text-sm text-[#6b7280]">{short(result.address)}</div>
                  </div>
                </div>

                <div className="mt-4 rounded-xl bg-[#f5f6f8] p-3 text-sm text-[#131a2b]">
                  <span className="font-semibold">Cuenta:</span> {result.company ? "Event Company" : "Usuario"}
                  {result.company && result.name && (
                    <div className="mt-1">
                      <span className="font-semibold">Empresa:</span> {result.name}
                    </div>
                  )}
                </div>

                {result.company && (
                  <Link
                    href="/events/create"
                    onClick={closeModal}
                    className="mt-5 flex w-full items-center justify-center gap-2 rounded-full bg-[#2bb3ec] py-3 font-semibold text-white shadow-md transition hover:bg-[#1ba5dd]"
                  >
                    <PlusIcon className="h-5 w-5" />
                    Crear evento
                  </Link>
                )}

                <button
                  onClick={closeModal}
                  className="mt-3 flex w-full items-center justify-center rounded-full border border-[#e5e7eb] bg-white py-3 font-semibold text-[#131a2b] transition hover:bg-[#f5f6f8]"
                >
                  Cerrar
                </button>
              </>
            ) : (
              <>
                <p className="mb-4 text-sm text-[#6b7280]">Tu wallet es tu identidad — conéctala para empezar.</p>
                <form className="flex flex-col gap-3" onSubmit={handleSubmit}>
                  {registeringAddress ? (
                    <div className="flex items-center gap-2 rounded-lg border border-[#bae6fd] bg-[#f0f9ff] px-3 py-2.5">
                      <UserCircleIcon className="h-4 w-4 shrink-0 text-[#2bb3ec]" />
                      <div className="min-w-0">
                        <div className="text-xs text-[#6b7280]">Wallet a registrar</div>
                        <div className="truncate font-mono text-xs font-medium text-[#131a2b]">{registeringAddress}</div>
                      </div>
                    </div>
                  ) : (
                    <button
                      type="button"
                      onClick={handleDetectWallet}
                      className="flex w-full cursor-pointer items-center justify-center gap-2 rounded-lg border border-dashed border-[#cbd1d9] bg-[#f5f6f8] px-3 py-2.5 text-sm text-[#6b7280] transition hover:border-[#2bb3ec] hover:text-[#2bb3ec]"
                    >
                      <UserCircleIcon className="h-4 w-4" />
                      Detectar wallet
                    </button>
                  )}

                  <label className="flex cursor-pointer items-center gap-2 text-sm text-[#131a2b]">
                    <input
                      type="checkbox"
                      checked={asCompany}
                      onChange={e => setAsCompany(e.target.checked)}
                      className="h-4 w-4 rounded border-[#cbd1d9] accent-[#2bb3ec]"
                    />
                    Registrarme como Event Company
                  </label>

                  {asCompany && (
                    <input
                      type="text"
                      placeholder="Nombre de la empresa"
                      value={companyName}
                      onChange={e => setCompanyName(e.target.value)}
                      className="w-full rounded-lg bg-[#ebeef3] px-4 py-3 text-[#131a2b] focus:outline-none focus:ring-2 focus:ring-[#2bb3ec]"
                    />
                  )}

                  {error && <div className="rounded-lg bg-[#fdecec] px-3 py-2 text-sm text-[#b42424]">{error}</div>}

                  <button
                    type="submit"
                    disabled={submitting}
                    className="mt-2 w-full cursor-pointer rounded-full bg-[#2bb3ec] py-3 font-semibold text-white shadow-md transition hover:bg-[#1ba5dd] disabled:opacity-60"
                  >
                    {submitting ? "Registrando..." : "Registrarme"}
                  </button>
                </form>
              </>
            )}
          </div>
        </div>
      )}
    </>
  );
};
