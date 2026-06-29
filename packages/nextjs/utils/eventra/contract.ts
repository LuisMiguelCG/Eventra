import { ethers } from "ethers";
import { CHAIN_ID, EVENTRA_ABI, EVENTRA_ADDRESS, RPC_URL } from "~~/contracts/eventra";

export const getReadContract = () =>
  new ethers.Contract(EVENTRA_ADDRESS, EVENTRA_ABI, new ethers.JsonRpcProvider(RPC_URL));

const CHAIN_ID_HEX = "0x" + CHAIN_ID.toString(16);

const ensureChain = async (eth: any) => {
  try {
    await eth.request({ method: "wallet_switchEthereumChain", params: [{ chainId: CHAIN_ID_HEX }] });
  } catch (err: any) {
    if (err?.code === 4902) {
      await eth.request({
        method: "wallet_addEthereumChain",
        params: [
          {
            chainId: CHAIN_ID_HEX,
            chainName: "AnvilTest",
            rpcUrls: [RPC_URL],
            nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
          },
        ],
      });
    } else {
      throw err;
    }
  }
};

export const connectWallet = async () => {
  const eth = (window as any).ethereum;
  if (!eth) throw new Error("Need Metamask");

  await eth.request({ method: "eth_requestAccounts" });
  await ensureChain(eth);

  const browser = new ethers.BrowserProvider(eth);
  const signer = await browser.getSigner();

  return { signer, address: await signer.getAddress() };
};

export const getWriteContract = (signer: ethers.Signer) => new ethers.Contract(EVENTRA_ADDRESS, EVENTRA_ABI, signer);

const ERROR_ES: Record<string, string> = {
  "Not Company": "Tu wallet no está registrada como empresa.",
  "Not User": "Tu wallet no está registrada como usuario.",
  "Company already has an event": "Esta empresa ya tiene un evento activo.",
  "Invalid Ticket Royalty": "El royalty debe estar entre 10 y 25.",
  "Invalid Start Time": "El inicio de venta debe ser una fecha futura.",
  "Invalid End Time": "El fin de venta debe ser una fecha futura.",
  "Invalid Date Event": "La fecha del evento debe ser futura.",
  "Invalid Sell Time": "El inicio de venta debe ser anterior al fin.",
  "Suspended user": "Tu cuenta está suspendida.",
  "Event not found": "El evento no existe.",
  "Event finished": "El evento ya ha pasado: no se puede cancelar.",
  "Event canceled": "El evento ya está cancelado.",
  "Event not finished yet": "El evento aún no ha terminado (espera 1 día tras la fecha).",
  "No funds available for withdrawal": "No hay fondos disponibles para retirar.",
  "Sales closed": "La venta de entradas no esta abierta.",
  "Event sold out": "El evento esta agotado.",
  "You can't buy your own ticket": "No puedes comprar tu propia entrada.",
  "Ticket is not in resell": "La entrada no esta en reventa.",
  "Ticket already in resell": "La entrada ya esta en reventa.",
  "This ticket does not belong to you": "Esta entrada no pertenece a tu wallet.",
  "Ticket not Canceled": "La entrada no esta cancelada.",
  "Invalid ticket price": "El precio de la entrada no es valido.",
  "Resell Price must be > 0": "El precio de reventa debe ser mayor que 0.",
  "You reached the max number of tickets you can buy for this event.":
    "Has alcanzado el maximo de entradas para este evento.",
};

const errorInterface = new ethers.Interface(EVENTRA_ABI);

const extractRevertData = (err: any): string | undefined =>
  err?.data ?? err?.info?.error?.data ?? err?.error?.data ?? err?.revert?.data;

export const parseContractError = (err: any): string => {
  if (err?.code === "ACTION_REJECTED") return "Has rechazado la transacción en MetaMask.";

  let name: string | undefined = err?.revert?.name;
  let args: any[] = err?.revert?.args ? Array.from(err.revert.args) : [];

  if (!name) {
    const data = extractRevertData(err);
    if (typeof data === "string" && data.length >= 10) {
      try {
        const parsed = errorInterface.parseError(data);
        if (parsed) {
          name = parsed.name;
          args = Array.from(parsed.args);
        }
      } catch {}
    }
  }

  if (name) {
    const str = args.find(a => typeof a === "string") as string | undefined;
    if (str) return ERROR_ES[str] ?? str;
    if (name === "InvalidAmount") return "La cantidad de ETH enviada no es la correcta.";
    return name;
  }

  return err?.shortMessage ?? err?.reason ?? err?.message ?? "Error en la transacción.";
};
