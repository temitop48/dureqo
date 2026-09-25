import type { Abi } from "viem";

// Minimal ABI copied from contracts/out/ContinuityVault.sol/ContinuityVault.json.
// The deployed contract remains the source of financial truth.
export const continuityVaultAbi = [
  { type: "function", name: "activateContinuity", inputs: [], outputs: [], stateMutability: "nonpayable" },
  { type: "function", name: "activeUntil", inputs: [], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "availableBalance", inputs: [], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "cancelCommitment", inputs: [{ name: "id", type: "uint256" }], outputs: [], stateMutability: "nonpayable" },
  { type: "function", name: "cancelRecovery", inputs: [], outputs: [], stateMutability: "nonpayable" },
  { type: "function", name: "checkIn", inputs: [], outputs: [], stateMutability: "nonpayable" },
  { type: "function", name: "commitmentCount", inputs: [], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "completeRecovery", inputs: [], outputs: [], stateMutability: "nonpayable" },
  { type: "function", name: "continuityActivated", inputs: [], outputs: [{ name: "", type: "bool" }], stateMutability: "view" },
  { type: "function", name: "continuityEligibleAt", inputs: [], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "createCommitment", inputs: [
    { name: "recipient", type: "address" },
    { name: "amount", type: "uint128" },
    { name: "interval", type: "uint64" },
    { name: "firstDue", type: "uint64" },
  ], outputs: [{ name: "id", type: "uint256" }], stateMutability: "nonpayable" },
  { type: "function", name: "deposit", inputs: [{ name: "amount", type: "uint256" }], outputs: [], stateMutability: "nonpayable" },
  { type: "function", name: "executeCommitment", inputs: [{ name: "id", type: "uint256" }], outputs: [], stateMutability: "nonpayable" },
  { type: "function", name: "getCommitment", inputs: [{ name: "id", type: "uint256" }], outputs: [{ name: "", type: "tuple", components: [
    { name: "recipient", type: "address" },
    { name: "amount", type: "uint128" },
    { name: "interval", type: "uint64" },
    { name: "nextDue", type: "uint64" },
    { name: "active", type: "bool" },
  ] }], stateMutability: "view" },
  { type: "function", name: "gracePeriod", inputs: [], outputs: [{ name: "", type: "uint64" }], stateMutability: "view" },
  { type: "function", name: "heartbeatInterval", inputs: [], outputs: [{ name: "", type: "uint64" }], stateMutability: "view" },
  { type: "function", name: "isFunded", inputs: [], outputs: [{ name: "", type: "bool" }], stateMutability: "view" },
  { type: "function", name: "lastHeartbeat", inputs: [], outputs: [{ name: "", type: "uint64" }], stateMutability: "view" },
  { type: "function", name: "mode", inputs: [], outputs: [{ name: "", type: "uint8" }], stateMutability: "view" },
  { type: "function", name: "owner", inputs: [], outputs: [{ name: "", type: "address" }], stateMutability: "view" },
  { type: "function", name: "protectedBalance", inputs: [], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "recoveryDelay", inputs: [], outputs: [{ name: "", type: "uint64" }], stateMutability: "view" },
  { type: "function", name: "recoveryRequestedAt", inputs: [], outputs: [{ name: "", type: "uint64" }], stateMutability: "view" },
  { type: "function", name: "requestRecovery", inputs: [], outputs: [], stateMutability: "nonpayable" },
  { type: "function", name: "usdg", inputs: [], outputs: [{ name: "", type: "address" }], stateMutability: "view" },
  { type: "function", name: "withdrawAvailable", inputs: [{ name: "recipient", type: "address" }, { name: "amount", type: "uint256" }], outputs: [], stateMutability: "nonpayable" },
] as const satisfies Abi;

export const usdgAbi = [
  { type: "function", name: "allowance", inputs: [{ name: "owner", type: "address" }, { name: "spender", type: "address" }], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "approve", inputs: [{ name: "spender", type: "address" }, { name: "amount", type: "uint256" }], outputs: [{ name: "", type: "bool" }], stateMutability: "nonpayable" },
  { type: "function", name: "balanceOf", inputs: [{ name: "account", type: "address" }], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "decimals", inputs: [], outputs: [{ name: "", type: "uint8" }], stateMutability: "view" },
  { type: "function", name: "name", inputs: [], outputs: [{ name: "", type: "string" }], stateMutability: "view" },
  { type: "function", name: "symbol", inputs: [], outputs: [{ name: "", type: "string" }], stateMutability: "view" },
] as const satisfies Abi;
