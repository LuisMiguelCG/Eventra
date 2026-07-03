import abi from "../../foundry/out/EventraContract.sol/EventraContract.json";

export const EVENTRA_ABI = abi.abi;
export const EVENTRA_ADDRESS = process.env.NEXT_PUBLIC_EVENTRA_ADDRESS as string;
export const RPC_URL = process.env.NEXT_PUBLIC_RPC_URL as string;
export const CHAIN_ID = Number(process.env.NEXT_PUBLIC_CHAIN_ID);
