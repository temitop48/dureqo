"use client";

import { useAccount, useConnect, useDisconnect, useReadContract, useSwitchChain } from "wagmi";
import { Button, StatusBadge, TrackedLabel } from "./foundation";
import { continuityVaultAbi } from "@/lib/web3/abis";
import { ARBITRUM_SEPOLIA_CHAIN_ID, publicWeb3Config } from "@/lib/web3/config";
import { normalizeWeb3Error } from "@/lib/web3/errors";

function shortenAddress(address: string) {
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}

export function WalletControl() {
  const { address, chainId, isConnected } = useAccount();
  const { connectors, connect, error: connectError, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, error: switchError, isPending: isSwitching } = useSwitchChain();
  const [onlyConnector] = connectors;
  const wrongNetwork = isConnected && chainId !== ARBITRUM_SEPOLIA_CHAIN_ID;

  if (!isConnected) {
    return (
      <div className="account-shell">
        <TrackedLabel>Account</TrackedLabel>
        {connectors.length <= 1 ? (
          <Button
            variant="quiet"
            disabled={isPending || connectors.length === 0}
            onClick={() => onlyConnector && connect({ connector: onlyConnector })}
            aria-label="Connect wallet"
          >
            {isPending ? "Connecting…" : connectors.length === 0 ? "Wallet unavailable" : "Connect Wallet"}
          </Button>
        ) : (
          connectors.map((connector) => (
            <Button
              key={connector.uid}
              variant="quiet"
              disabled={isPending}
              onClick={() => connect({ connector })}
              aria-label={`Connect ${connector.name}`}
            >
              {isPending ? "Connecting…" : `Connect ${connector.name}`}
            </Button>
          ))
        )}
        {connectError ? <span className="web3-inline-error">{normalizeWeb3Error(connectError)}</span> : null}
      </div>
    );
  }

  return (
    <div className="account-shell account-shell--connected">
      <TrackedLabel>Account</TrackedLabel>
      <Button variant="quiet" onClick={() => disconnect()} aria-label="Disconnect wallet">
        {address ? shortenAddress(address) : "Connected"}
      </Button>
      {wrongNetwork ? (
        <>
          <Button
            variant="solid"
            disabled={isSwitching}
            onClick={() => switchChain({ chainId: ARBITRUM_SEPOLIA_CHAIN_ID })}
            aria-label="Switch wallet to Arbitrum Sepolia"
          >
            {isSwitching ? "Switching…" : "Switch network"}
          </Button>
          {switchError ? <span className="web3-inline-error">{normalizeWeb3Error(switchError)}</span> : null}
        </>
      ) : null}
    </div>
  );
}

export function Web3IntegrationStatus() {
  const { chainId: walletChainId, isConnected } = useAccount();
  const owner = useReadContract({ address: publicWeb3Config.vaultAddress, abi: continuityVaultAbi, chainId: ARBITRUM_SEPOLIA_CHAIN_ID, functionName: "owner" });
  const configuredUsdg = useReadContract({ address: publicWeb3Config.vaultAddress, abi: continuityVaultAbi, chainId: ARBITRUM_SEPOLIA_CHAIN_ID, functionName: "usdg" });
  const mode = useReadContract({ address: publicWeb3Config.vaultAddress, abi: continuityVaultAbi, chainId: ARBITRUM_SEPOLIA_CHAIN_ID, functionName: "mode" });
  const failed = owner.isError || configuredUsdg.isError || mode.isError;
  const loading = owner.isLoading || configuredUsdg.isLoading || mode.isLoading;
  const walletWrongNetwork = isConnected && walletChainId !== ARBITRUM_SEPOLIA_CHAIN_ID;
  const walletReadiness = !isConnected ? "Connect wallet to transact" : walletWrongNetwork ? "Switch wallet network" : "Wallet on Arbitrum Sepolia";

  return (
    <span className="integration-status" id="activity">
      <span>Vault link</span>
      <strong>{loading ? "Reading…" : failed ? "Read unavailable" : "Vault read OK"}</strong>
      {!loading && !failed && typeof owner.data === "string" ? <small>Owner {shortenAddress(owner.data)}</small> : null}
      {!loading && !failed && typeof configuredUsdg.data === "string" && configuredUsdg.data.toLowerCase() !== publicWeb3Config.usdgAddress.toLowerCase() ? (
        <small className="web3-inline-error">Configured USDG mismatch</small>
      ) : null}
      {!loading && !failed && typeof mode.data === "number" ? <small>Mode {mode.data.toString()}</small> : null}
      {failed ? <small>Arbitrum Sepolia RPC or contract read failed.</small> : null}
      {!failed ? <small>{walletReadiness}</small> : null}
    </span>
  );
}

export function ConnectionStatusBadge() {
  const { isConnected } = useAccount();
  return <StatusBadge status={isConnected ? "active" : "neutral"} />;
}
