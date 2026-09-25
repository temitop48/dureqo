import { getAddress, parseUnits } from "viem";

export const MAX_UINT64 = (BigInt(2) ** BigInt(64)) - BigInt(1);
export const MAX_UINT128 = (BigInt(2) ** BigInt(128)) - BigInt(1);

export function parsePositiveTokenAmount(value: string, decimals: number): bigint {
  const parsed = parseUnits(value.trim(), decimals);
  if (parsed <= BigInt(0)) throw new Error("Amount must be greater than zero.");
  return parsed;
}

export function parseBoundedInteger(value: string, max: bigint, label: string): bigint {
  if (!/^\d+$/.test(value.trim())) throw new Error(`${label} must be a whole number.`);
  const parsed = BigInt(value.trim());
  if (parsed > max) throw new Error(`${label} is too large.`);
  return parsed;
}

export function parseAddress(value: string, label = "Recipient"): `0x${string}` {
  try {
    return getAddress(value.trim());
  } catch {
    throw new Error(`${label} must be a valid wallet address.`);
  }
}

export function parseFirstDue(value: string): bigint {
  const milliseconds = Date.parse(value);
  if (!Number.isFinite(milliseconds)) throw new Error("First due must be a valid date and time.");
  return BigInt(Math.floor(milliseconds / 1000));
}
