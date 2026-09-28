"use client";

import { useCallback, useEffect } from "react";
import type { Address } from "viem";
import { useAccount, useReadContract, useWaitForTransactionReceipt, useWriteContract } from "wagmi";
import { continuityVaultAbi, continuityVaultFactoryAbi } from "@/lib/web3/abis";
import { ARBITRUM_SEPOLIA_CHAIN_ID, publicWeb3Config } from "@/lib/web3/config";
import { normalizeWeb3Error } from "@/lib/web3/errors";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

export type VaultDiscoveryStatus =
  | "disconnected"
  | "wrong-network"
  | "discovering"
  | "no-vault"
  | "creation-pending"
  | "ready"
  | "discovery-error"
  | "creation-error";

function isUsableAddress(value: unknown): value is Address {
  return typeof value === "string" && value.toLowerCase() !== ZERO_ADDRESS;
}

export function useVaultDiscovery() {
  const account = useAccount();
  const connected = account.isConnected && Boolean(account.address);
  const correctNetwork = connected && account.chainId === ARBITRUM_SEPOLIA_CHAIN_ID;
  const mapping = useReadContract({
    address: publicWeb3Config.factoryAddress,
    abi: continuityVaultFactoryAbi,
    chainId: ARBITRUM_SEPOLIA_CHAIN_ID,
    functionName: "vaultCreatedBy",
    args: account.address ? [account.address] : undefined,
    query: { enabled: Boolean(correctNetwork && account.address) },
  });
  const candidateVault = isUsableAddress(mapping.data) ? mapping.data : undefined;
  const owner = useReadContract({
    address: candidateVault,
    abi: continuityVaultAbi,
    chainId: ARBITRUM_SEPOLIA_CHAIN_ID,
    functionName: "owner",
    query: { enabled: Boolean(correctNetwork && candidateVault) },
  });
  const write = useWriteContract();
  const receipt = useWaitForTransactionReceipt({
    chainId: ARBITRUM_SEPOLIA_CHAIN_ID,
    hash: write.data,
    query: { enabled: Boolean(write.data) },
  });
  const { refetch: refetchMapping } = mapping;
  const isBusy = write.isPending || receipt.isLoading;

  const createVault = useCallback(() => {
    if (isBusy) throw new Error("Vault creation is already pending.");
    if (!connected || !account.address) throw new Error("Connect a wallet before creating a vault.");
    if (!correctNetwork) throw new Error("Switch to Arbitrum Sepolia before creating a vault.");
    if (candidateVault) throw new Error("This wallet already has a created vault.");

    write.writeContract({
      abi: continuityVaultFactoryAbi,
      address: publicWeb3Config.factoryAddress,
      args: [],
      chainId: ARBITRUM_SEPOLIA_CHAIN_ID,
      functionName: "createVault",
    });
  }, [account.address, candidateVault, connected, correctNetwork, isBusy, write]);

  useEffect(() => {
    if (receipt.isSuccess) void refetchMapping();
  }, [receipt.isSuccess, refetchMapping]);

  let status: VaultDiscoveryStatus;
  if (!connected) status = "disconnected";
  else if (!correctNetwork) status = "wrong-network";
  else if (isBusy) status = "creation-pending";
  else if (write.error || receipt.error) status = "creation-error";
  else if (mapping.isPending) status = "discovering";
  else if (mapping.isError || (candidateVault && owner.isError)) status = "discovery-error";
  else if (receipt.isSuccess && mapping.data !== undefined && !candidateVault) status = "discovery-error";
  else if (!candidateVault) status = "no-vault";
  else if (owner.isPending || owner.data === undefined) status = "discovering";
  else status = "ready";

  const error = write.error ?? receipt.error ?? mapping.error ?? owner.error;

  return {
    ...account,
    status,
    vaultAddress: status === "ready" ? candidateVault : undefined,
    createdVaultAddress: candidateVault,
    owner: typeof owner.data === "string" ? owner.data : undefined,
    isController: Boolean(account.address && typeof owner.data === "string" && account.address.toLowerCase() === owner.data.toLowerCase()),
    isBusy,
    hash: write.data,
    receipt,
    phase: receipt.isSuccess ? "confirmed" : receipt.isLoading ? "confirming" : write.error ? "failed" : write.isPending ? "awaiting-signature" : write.data ? "submitted" : "idle",
    errorMessage: error
      ? normalizeWeb3Error(error)
      : status === "discovery-error" && receipt.isSuccess
        ? "The confirmed creation was not returned by the factory mapping."
        : undefined,
    createVault,
    refreshDiscovery: refetchMapping,
  };
}
