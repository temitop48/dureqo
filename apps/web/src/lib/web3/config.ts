import { getAddress } from "viem";
import { arbitrumSepolia } from "viem/chains";
import { createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";

export const ARBITRUM_SEPOLIA_CHAIN_ID = 421614;

function requiredPublicEnv(name: string, value: string | undefined): string {
  if (!value) {
    throw new Error(`Missing required public Web3 configuration: ${name}`);
  }
  return value.trim();
}

function validateRpcUrl(value: string): string {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error("NEXT_PUBLIC_ARBITRUM_SEPOLIA_RPC_URL must be a valid URL");
  }

  if (url.protocol !== "https:" && url.protocol !== "http:") {
    throw new Error("NEXT_PUBLIC_ARBITRUM_SEPOLIA_RPC_URL must use HTTP or HTTPS");
  }

  return url.toString();
}

function validateAddress(name: string, value: string): `0x${string}` {
  try {
    return getAddress(value) as `0x${string}`;
  } catch {
    throw new Error(`${name} must be a valid Ethereum address`);
  }
}

export const publicWeb3Config = {
  chainId: ARBITRUM_SEPOLIA_CHAIN_ID,
  rpcUrl: validateRpcUrl(
    requiredPublicEnv(
      "NEXT_PUBLIC_ARBITRUM_SEPOLIA_RPC_URL",
      process.env.NEXT_PUBLIC_ARBITRUM_SEPOLIA_RPC_URL,
    ),
  ),
  vaultAddress: validateAddress(
    "NEXT_PUBLIC_CONTINUITY_VAULT_ADDRESS",
    requiredPublicEnv(
      "NEXT_PUBLIC_CONTINUITY_VAULT_ADDRESS",
      process.env.NEXT_PUBLIC_CONTINUITY_VAULT_ADDRESS,
    ),
  ),
  usdgAddress: validateAddress(
    "NEXT_PUBLIC_USDG_ADDRESS",
    requiredPublicEnv("NEXT_PUBLIC_USDG_ADDRESS", process.env.NEXT_PUBLIC_USDG_ADDRESS),
  ),
} as const;

if (arbitrumSepolia.id !== publicWeb3Config.chainId) {
  throw new Error("The configured Arbitrum Sepolia chain ID does not match viem");
}

export const wagmiConfig = createConfig({
  chains: [arbitrumSepolia],
  connectors: [injected({ shimDisconnect: true })],
  ssr: true,
  transports: {
    [arbitrumSepolia.id]: http(publicWeb3Config.rpcUrl),
  },
});
