"use client";

import { useCallback } from "react";
import type { ContractFunctionArgs } from "viem";
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from "wagmi";
import { continuityVaultAbi, usdgAbi } from "@/lib/web3/abis";
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

export function useVaultTransaction(vaultAddress: `0x${string}` | undefined) {
  const { chainId } = useAccount();
  const write = useWriteContract();
  const receipt = useWaitForTransactionReceipt({
    chainId: ARBITRUM_SEPOLIA_CHAIN_ID,
    hash: write.data,
    query: { enabled: Boolean(write.data) },
  });
  const isBusy = write.isPending || receipt.isLoading;

  const writeVault = useCallback(
    (request: VaultWriteRequest) => {
      if (isBusy) throw new Error("A wallet transaction is already pending.");
      if (chainId !== ARBITRUM_SEPOLIA_CHAIN_ID) {
        throw new Error("Writes are blocked until the wallet is on Arbitrum Sepolia.");
      }
      if (!vaultAddress) throw new Error("No runtime vault has been discovered.");

      write.writeContract({
        abi: continuityVaultAbi,
        address: vaultAddress,
        args: request.args,
        chainId: ARBITRUM_SEPOLIA_CHAIN_ID,
        functionName: request.functionName,
      });
    },
    [chainId, isBusy, vaultAddress, write],
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
    errorMessage: write.error || receipt.error ? normalizeWeb3Error(write.error ?? receipt.error) : undefined,
    writeVault,
    isConfirming: receipt.isLoading,
    isConfirmed: receipt.isSuccess,
    isBusy,
  };
}

export function useUsdGApproval(vaultAddress: `0x${string}` | undefined) {
  const { chainId } = useAccount();
  const write = useWriteContract();
  const receipt = useWaitForTransactionReceipt({
    chainId: ARBITRUM_SEPOLIA_CHAIN_ID,
    hash: write.data,
    query: { enabled: Boolean(write.data) },
  });
  const isBusy = write.isPending || receipt.isLoading;

  const approve = useCallback(
    (amount: bigint) => {
      if (isBusy) throw new Error("A wallet transaction is already pending.");
      if (chainId !== ARBITRUM_SEPOLIA_CHAIN_ID) {
        throw new Error("Approvals are blocked until the wallet is on Arbitrum Sepolia.");
      }
      if (!vaultAddress) throw new Error("No runtime vault has been discovered.");

      write.writeContract({
        abi: usdgAbi,
        address: publicWeb3Config.usdgAddress,
        args: [vaultAddress, amount],
        chainId: ARBITRUM_SEPOLIA_CHAIN_ID,
        functionName: "approve",
      });
    },
    [chainId, isBusy, vaultAddress, write],
  );

  const phase = receipt.isSuccess
    ? "confirmed"
    : receipt.isLoading
      ? "confirming"
      : write.error
        ? "failed"
        : write.isPending
          ? "awaiting-signature"
          : write.data
            ? "submitted"
            : "idle";

  return {
    ...write,
    hash: write.data,
    phase,
    errorMessage: write.error || receipt.error ? normalizeWeb3Error(write.error ?? receipt.error) : undefined,
    isConfirming: receipt.isLoading,
    isConfirmed: receipt.isSuccess,
    isBusy,
    approve,
  };
}
