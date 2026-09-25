"use client";

import { useMemo } from "react";
import type { Address, ContractFunctionParameters } from "viem";
import { useReadContracts } from "wagmi";
import { continuityVaultAbi, usdgAbi } from "@/lib/web3/abis";
import { ARBITRUM_SEPOLIA_CHAIN_ID, publicWeb3Config } from "@/lib/web3/config";

export type Commitment = {
  recipient: Address;
  amount: bigint;
  interval: bigint;
  nextDue: bigint;
  active: boolean;
};

function isCommitment(value: unknown): value is Commitment {
  if (!value || typeof value !== "object") return false;
  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.recipient === "string" &&
    typeof candidate.amount === "bigint" &&
    typeof candidate.interval === "bigint" &&
    typeof candidate.nextDue === "bigint" &&
    typeof candidate.active === "boolean"
  );
}

export function useVaultReads() {
  const contracts = useMemo(
    () =>
      [
        { address: publicWeb3Config.usdgAddress, abi: usdgAbi, functionName: "balanceOf", args: [publicWeb3Config.vaultAddress] },
        { address: publicWeb3Config.vaultAddress, abi: continuityVaultAbi, functionName: "protectedBalance" },
        { address: publicWeb3Config.vaultAddress, abi: continuityVaultAbi, functionName: "availableBalance" },
        { address: publicWeb3Config.vaultAddress, abi: continuityVaultAbi, functionName: "isFunded" },
        { address: publicWeb3Config.vaultAddress, abi: continuityVaultAbi, functionName: "owner" },
        { address: publicWeb3Config.vaultAddress, abi: continuityVaultAbi, functionName: "mode" },
        { address: publicWeb3Config.vaultAddress, abi: continuityVaultAbi, functionName: "commitmentCount" },
        { address: publicWeb3Config.usdgAddress, abi: usdgAbi, functionName: "decimals" },
      ] as const,
    [],
  );
  const query = useReadContracts({
    allowFailure: false,
    chainId: ARBITRUM_SEPOLIA_CHAIN_ID,
    contracts,
  });

  return {
    ...query,
    vaultBalance: query.data?.[0],
    protectedBalance: query.data?.[1],
    availableBalance: query.data?.[2],
    isFunded: query.data?.[3],
    owner: query.data?.[4],
    mode: query.data?.[5],
    commitmentCount: query.data?.[6],
    decimals: query.data?.[7],
  };
}

export function useConnectedUsdGReads(address: Address | undefined) {
  const contracts = useMemo<readonly ContractFunctionParameters[]>(() => {
    if (!address) return [];
    return [
      { address: publicWeb3Config.usdgAddress, abi: usdgAbi, functionName: "balanceOf", args: [address] },
      { address: publicWeb3Config.usdgAddress, abi: usdgAbi, functionName: "allowance", args: [address, publicWeb3Config.vaultAddress] },
    ] as const;
  }, [address]);
  const query = useReadContracts({
    allowFailure: false,
    chainId: ARBITRUM_SEPOLIA_CHAIN_ID,
    contracts,
    query: { enabled: Boolean(address) },
  });

  return {
    ...query,
    balance: query.data?.[0],
    allowance: query.data?.[1],
  };
}

export function useCommitmentReads(commitmentCount: bigint | undefined) {
  const ids = useMemo(() => {
    if (commitmentCount === undefined || commitmentCount > BigInt(1000)) return [];
    return Array.from({ length: Number(commitmentCount) }, (_, index) => BigInt(index + 1));
  }, [commitmentCount]);
  const contracts = useMemo(
    () =>
      ids.map((id) => ({
        address: publicWeb3Config.vaultAddress,
        abi: continuityVaultAbi,
        functionName: "getCommitment" as const,
        args: [id] as const,
      })),
    [ids],
  );
  const query = useReadContracts({
    allowFailure: false,
    chainId: ARBITRUM_SEPOLIA_CHAIN_ID,
    contracts,
    query: { enabled: commitmentCount !== undefined && commitmentCount <= BigInt(1000) },
  });

  const commitments = query.data
    ?.map((value, index) => (isCommitment(value) ? { id: ids[index]!, ...value } : undefined))
    .filter((value): value is { id: bigint } & Commitment => value !== undefined) ?? [];

  return { ...query, commitments, tooMany: commitmentCount !== undefined && commitmentCount > BigInt(1000) };
}
