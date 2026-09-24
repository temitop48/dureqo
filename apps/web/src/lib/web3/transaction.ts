"use client";

import { useCallback } from "react";
import type { ContractFunctionArgs } from "viem";
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from "wagmi";
import { continuityVaultAbi } from "@/lib/web3/abis";
import { ARBITRUM_SEPOLIA_CHAIN_ID, publicWeb3Config } from "@/lib/web3/config";
import { normalizeWeb3Error } from "@/lib/web3/errors";

export type TransactionPhase =
  | "idle"
  | "awaiting-signature"
  | "submitted"
  | "confirming"
  | "confirmed"
  | "rejected"
  | "failed";

type SupportedVaultWriteName =
  | "activateContinuity"
  | "cancelCommitment"
  | "cancelRecovery"
  | "checkIn"
  | "completeRecovery"
  | "createCommitment"
  | "deposit"
  | "executeCommitment"
  | "requestRecovery"
  | "withdrawAvailable";

export type VaultWriteRequest = {
  [Name in SupportedVaultWriteName]: {
    functionName: Name;
    args: ContractFunctionArgs<typeof continuityVaultAbi, "nonpayable", Name>;
  };
}[SupportedVaultWriteName];

export function useVaultTransaction() {
  const { chainId } = useAccount();
  const write = useWriteContract();
  const receipt = useWaitForTransactionReceipt({
    chainId: ARBITRUM_SEPOLIA_CHAIN_ID,
    hash: write.data,
    query: { enabled: Boolean(write.data) },
  });

  const writeVault = useCallback(
    (request: VaultWriteRequest) => {
      if (chainId !== ARBITRUM_SEPOLIA_CHAIN_ID) {
        throw new Error("Writes are blocked until the wallet is on Arbitrum Sepolia.");
      }

      write.writeContract({
        abi: continuityVaultAbi,
        address: publicWeb3Config.vaultAddress,
        args: request.args,
        chainId: ARBITRUM_SEPOLIA_CHAIN_ID,
        functionName: request.functionName,
      });
    },
    [chainId, write],
  );

  let phase: TransactionPhase = "idle";
  if (write.error) phase = write.error.name?.toLowerCase().includes("userrejected") ? "rejected" : "failed";
  else if (receipt.error) phase = "failed";
  else if (receipt.isSuccess) phase = "confirmed";
  else if (receipt.isLoading) phase = "confirming";
  else if (write.data) phase = "submitted";
  else if (write.isPending) phase = "awaiting-signature";

  return {
    ...write,
    hash: write.data,
    phase,
    errorMessage: normalizeWeb3Error(write.error ?? receipt.error),
    writeVault,
    isConfirming: receipt.isLoading,
    isConfirmed: receipt.isSuccess,
  };
}
