export function normalizeWeb3Error(error: unknown): string {
  if (!error) return "An unknown Web3 error occurred.";

  const candidate = error as { name?: string; shortMessage?: string; message?: string };
  const name = candidate.name?.toLowerCase() ?? "";
  const message = candidate.shortMessage ?? candidate.message ?? "";
  const normalized = message.toLowerCase();

  if (name.includes("userrejected") || normalized.includes("user rejected") || normalized.includes("user denied")) {
    return "The wallet request was rejected.";
  }
  if (name.includes("connectornotfound") || normalized.includes("no injected provider") || normalized.includes("connector not found")) {
    return "No compatible injected wallet was found.";
  }
  if (name.includes("switchchain") || normalized.includes("switch chain") || normalized.includes("switch to arbitrum sepolia")) {
    return "The wallet could not switch to Arbitrum Sepolia.";
  }
  if (normalized.includes("rpc") || normalized.includes("network") || normalized.includes("transport")) {
    return "The network request failed. Check the wallet and RPC connection.";
  }
  if (normalized.includes("execution reverted") || normalized.includes("transaction reverted") || name.includes("contract")) {
    return "The contract rejected the transaction.";
  }

  return "The Web3 request could not be completed.";
}
