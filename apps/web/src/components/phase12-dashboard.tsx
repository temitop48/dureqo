"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { formatUnits, type Address } from "viem";
import { useAccount } from "wagmi";
import { Button, Divider, PaperCard, StatusBadge, TrackedLabel } from "./foundation";
import { useConnectedUsdGReads, useCommitmentReads, useVaultReads, type Commitment } from "@/lib/web3/reads";
import { ARBITRUM_SEPOLIA_CHAIN_ID } from "@/lib/web3/config";
import { normalizeWeb3Error } from "@/lib/web3/errors";
import { useUsdGApproval, useVaultTransaction } from "@/lib/web3/transaction";
import { useVaultDiscovery } from "@/lib/web3/vault-discovery";
import { MAX_UINT128, MAX_UINT64, parseAddress, parseBoundedInteger, parseFirstDue, parsePositiveTokenAmount } from "@/lib/web3/validation";

const MODE_ACTIVE = 0;
const MODE_CAUTION = 1;
const MODE_CONTINUITY = 2;

function displayUsd(value: unknown, decimals: number | undefined) {
  if (typeof value !== "bigint" || decimals === undefined) return "—";
  return `${formatUnits(value, decimals)} USDG`;
}

function displayInteger(value: unknown) {
  return typeof value === "bigint" ? value.toString() : "—";
}

function displayDate(value: bigint) {
  const maxSeconds = BigInt(Math.floor(Number.MAX_SAFE_INTEGER / 1000));
  if (value > maxSeconds) return `Unix ${value.toString()}`;
  const date = new Date(Number(value) * 1000);
  const pad = (part: number) => part.toString().padStart(2, "0");
  return `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())} ${pad(date.getUTCHours())}:${pad(date.getUTCMinutes())}:${pad(date.getUTCSeconds())} UTC`;
}

function shortenAddress(address: string) {
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}

function modeName(mode: number | undefined) {
  if (mode === MODE_ACTIVE) return "Active";
  if (mode === MODE_CAUTION) return "Caution";
  if (mode === MODE_CONTINUITY) return "Continuity";
  return "Reading…";
}

type OperationalStatus = "active" | "caution" | "continuity" | "neutral";

function ControllerModeLabel({ status, label, connected }: { status: OperationalStatus; label: string; connected: boolean }) {
  return (
    <div className="operation-card__authority">
      <TrackedLabel>Identity / role</TrackedLabel>
      <strong>{label}</strong>
      <div className="operation-card__mode">
        <span>Operational mode</span>
        {connected ? <StatusBadge status={status} /> : <strong>Connect wallet to view</strong>}
      </div>
    </div>
  );
}

function formatDuration(seconds: bigint | undefined) {
  if (seconds === undefined) return "—";
  const days = seconds / BigInt(86400);
  const hours = (seconds % BigInt(86400)) / BigInt(3600);
  const minutes = (seconds % BigInt(3600)) / BigInt(60);
  const remainder = seconds % BigInt(60);
  const parts = [
    days > BigInt(0) ? `${days}d` : "",
    hours > BigInt(0) ? `${hours}h` : "",
    minutes > BigInt(0) ? `${minutes}m` : "",
    remainder > BigInt(0) || seconds === BigInt(0) ? `${remainder}s` : "",
  ].filter(Boolean);
  return parts.join(" ");
}

function errorText(error: unknown) {
  return normalizeWeb3Error(error);
}

function useRefreshReads(vaultAddress: Address | undefined) {
  const vault = useVaultReads(vaultAddress);
  const wallet = useAccount();
  const token = useConnectedUsdGReads(wallet.address, vaultAddress);
  const commitmentCount = typeof vault.commitmentCount === "bigint" ? vault.commitmentCount : undefined;
  const commitments = useCommitmentReads(vaultAddress, commitmentCount);
  const { refetch: refreshVault } = vault;
  const { refetch: refreshToken } = token;
  const { refetch: refreshCommitments } = commitments;
  const refresh = useCallback(
    () => Promise.all([refreshVault(), refreshToken(), refreshCommitments()]),
    [refreshCommitments, refreshToken, refreshVault],
  );
  return { vault, wallet, token, commitments, refresh };
}

function TransactionNote({ label, phase, error }: { label: string; phase: string; error?: string }) {
  if (phase === "idle" && !error) return null;
  const phaseCopy: Record<string, string> = {
    "awaiting-signature": "Wallet confirmation requested.",
    submitted: "Transaction submitted.",
    confirming: "Confirming on Arbitrum Sepolia…",
    confirmed: "Confirmed onchain.",
    rejected: "Wallet confirmation was rejected.",
    failed: "Transaction failed or reverted.",
  };
  return (
    <p className={`transaction-note transaction-note--${error ? "error" : phase}`} role={error ? "alert" : undefined}>
      {error ? `${label}: ${error}` : `${label}: ${phaseCopy[phase] ?? phase}`}
    </p>
  );
}

function BalanceCard({ title, value, decimals, detail, className = "" }: { title: string; value: unknown; decimals: number | undefined; detail: string; className?: string }) {
  return (
    <PaperCard className={`operational-card ${className}`}>
      <div className="operational-card__header"><h2>{title}</h2><span className="card-menu">USDG</span></div>
      <div className="live-value"><p>{displayUsd(value, decimals)}</p><small>{detail}</small></div>
    </PaperCard>
  );
}

function CommitmentRow({ commitment, decimals, currentTime, canCancel, canExecute, pending, onCancel, onExecute }: { commitment: { id: bigint } & Commitment; decimals: number | undefined; currentTime: bigint | null; canCancel: boolean; canExecute: boolean; pending: boolean; onCancel: (id: bigint) => void; onExecute: (id: bigint) => void }) {
  const due = currentTime !== null && commitment.active && currentTime >= commitment.nextDue;
  return (
    <div className="commitment-row">
      <div className="commitment-row__id"><TrackedLabel>ID</TrackedLabel><strong>{commitment.id.toString()}</strong></div>
      <div><TrackedLabel>Recipient</TrackedLabel><span className="mono-value">{commitment.recipient}</span></div>
      <div><TrackedLabel>Amount</TrackedLabel><strong>{displayUsd(commitment.amount, decimals)}</strong></div>
      <div><TrackedLabel>Schedule</TrackedLabel><span>{commitment.interval === BigInt(0) ? "One-time" : `Recurring · ${commitment.interval.toString()}s`}</span></div>
      <div><TrackedLabel>Next due</TrackedLabel><span>{displayDate(commitment.nextDue)}</span></div>
      <div className="commitment-row__status"><StatusBadge status={commitment.active ? due ? "caution" : "active" : "neutral"} /><span>{commitment.active ? due ? "Due" : "Active" : "Completed / cancelled"}</span></div>
      <div className="commitment-row__actions">
        {commitment.active && due ? <Button variant="solid" disabled={!canExecute || pending} onClick={() => onExecute(commitment.id)}>{pending ? "Pending…" : "Execute"}</Button> : <span className="action-hint">{commitment.active ? "Not due" : "No action"}</span>}
        {commitment.active ? <Button variant="quiet" disabled={!canCancel || pending} onClick={() => onCancel(commitment.id)}>Cancel</Button> : null}
      </div>
    </div>
  );
}

export function Phase12Dashboard() {
  const discovery = useVaultDiscovery();
  const { vault, wallet, token, commitments, refresh } = useRefreshReads(discovery.vaultAddress);
  const vaultTx = useVaultTransaction(discovery.vaultAddress);
  const approvalTx = useUsdGApproval(discovery.vaultAddress);
  const [depositAmount, setDepositAmount] = useState("");
  const [createRecipient, setCreateRecipient] = useState("");
  const [createAmount, setCreateAmount] = useState("");
  const [commitmentType, setCommitmentType] = useState<"one-time" | "recurring">("one-time");
  const [interval, setInterval] = useState("");
  const [firstDue, setFirstDue] = useState("");
  const [withdrawRecipient, setWithdrawRecipient] = useState("");
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [formError, setFormError] = useState<string | null>(null);
  const [activeModal, setActiveModal] = useState<"deposit" | "withdraw" | null>(null);
  const modalRef = useRef<HTMLElement | null>(null);
  const modalOriginRef = useRef<HTMLButtonElement | null>(null);
  const lastConfirmedHash = useRef<string | undefined>(undefined);
  const [currentTime, setCurrentTime] = useState<bigint | null>(null);
  const decimals = typeof vault.decimals === "number" ? vault.decimals : undefined;
  const connected = wallet.isConnected;
  const correctNetwork = connected && wallet.chainId === ARBITRUM_SEPOLIA_CHAIN_ID;
  const vaultReady = discovery.status === "ready" && Boolean(discovery.vaultAddress);
  const operationalMode = typeof vault.mode === "number" ? vault.mode : undefined;
  const active = operationalMode === MODE_ACTIVE;
  const caution = operationalMode === MODE_CAUTION;
  const continuity = operationalMode === MODE_CONTINUITY;
  const controller = vaultReady && correctNetwork && discovery.isController;
  const controllerActive = controller && active;
  const controllerContinuity = controller && continuity;
  const recoveryRequestedAt = typeof vault.recoveryRequestedAt === "bigint" ? vault.recoveryRequestedAt : undefined;
  const recoveryDelay = typeof vault.recoveryDelay === "bigint" ? vault.recoveryDelay : undefined;
  const activeUntil = typeof vault.activeUntil === "bigint" ? vault.activeUntil : undefined;
  const continuityEligibleAt = typeof vault.continuityEligibleAt === "bigint" ? vault.continuityEligibleAt : undefined;
  const recoveryRequested = recoveryRequestedAt !== undefined && recoveryRequestedAt > BigInt(0);
  const recoveryReadyAt = recoveryRequested && recoveryDelay !== undefined
    ? recoveryRequestedAt! + recoveryDelay
    : undefined;
  const recoveryReady = recoveryReadyAt !== undefined && currentTime !== null && currentTime >= recoveryReadyAt;
  const activeWindowElapsed = currentTime !== null && activeUntil !== undefined && currentTime > activeUntil;
  const activeUntilRemaining = currentTime !== null && activeUntil !== undefined && currentTime <= activeUntil ? activeUntil - currentTime : undefined;
  const eligibilityRemaining = currentTime !== null && continuityEligibleAt !== undefined && currentTime < continuityEligibleAt ? continuityEligibleAt - currentTime : undefined;
  const transactionPending = vaultTx.isBusy || approvalTx.isBusy || discovery.isBusy;

  useEffect(() => {
    const clock = window.setInterval(() => {
      setCurrentTime(BigInt(Math.floor(Date.now() / 1000)));
    }, 1_000);
    return () => window.clearInterval(clock);
  }, []);

  useEffect(() => {
    if (approvalTx.isConfirmed && approvalTx.hash !== lastConfirmedHash.current) {
      lastConfirmedHash.current = approvalTx.hash;
      void refresh();
    }
  }, [approvalTx.hash, approvalTx.isConfirmed, refresh]);

  useEffect(() => {
    if (vaultTx.isConfirmed && vaultTx.hash !== lastConfirmedHash.current) {
      lastConfirmedHash.current = vaultTx.hash;
      void refresh();
    }
  }, [refresh, vaultTx.hash, vaultTx.isConfirmed]);

  const runFormAction = useCallback((action: () => void) => {
    setFormError(null);
    try { action(); } catch (error) { setFormError(error instanceof Error ? error.message : errorText(error)); }
  }, []);

  const parsedDeposit = useMemo(() => {
    if (!depositAmount || decimals === undefined) return undefined;
    try { return parsePositiveTokenAmount(depositAmount, decimals); } catch { return undefined; }
  }, [decimals, depositAmount]);
  const depositNeedsApproval = parsedDeposit !== undefined && (typeof token.allowance !== "bigint" || token.allowance < parsedDeposit);
  const depositReady = Boolean(parsedDeposit !== undefined && connected && correctNetwork && typeof token.balance === "bigint" && token.balance >= parsedDeposit && !depositNeedsApproval && !transactionPending);

  const submitDepositApproval = () => runFormAction(() => {
    if (parsedDeposit === undefined) throw new Error("Enter a valid USDG amount.");
    if (!connected || !correctNetwork || !vaultReady) throw new Error("Discover a vault on Arbitrum Sepolia first.");
    if (typeof token.balance !== "bigint" || token.balance < parsedDeposit) throw new Error("Wallet USDG balance is insufficient.");
    approvalTx.approve(parsedDeposit);
  });

  const submitDeposit = () => runFormAction(() => {
    if (parsedDeposit === undefined) throw new Error("Enter a valid USDG amount.");
    if (!vaultReady || !depositReady) throw new Error("Approve the exact deposit amount before depositing.");
    vaultTx.writeVault({ functionName: "deposit", args: [parsedDeposit] });
  });

  const submitCreate = () => runFormAction(() => {
    if (!controllerActive) throw new Error("Only the controller on Active mode can create commitments.");
    if (decimals === undefined) throw new Error("USDG decimals are still loading.");
    const recipient = parseAddress(createRecipient);
    const amount = parsePositiveTokenAmount(createAmount, decimals);
    if (amount > MAX_UINT128) throw new Error("Commitment amount exceeds uint128.");
    const intervalValue = commitmentType === "one-time" ? BigInt(0) : parseBoundedInteger(interval, MAX_UINT64, "Recurring interval");
    if (commitmentType === "recurring" && intervalValue === BigInt(0)) throw new Error("Recurring interval must be greater than zero.");
    const due = parseFirstDue(firstDue);
    if (due > MAX_UINT64) throw new Error("First due exceeds uint64.");
    if (due < BigInt(Math.floor(Date.now() / 1000))) throw new Error("First due cannot be in the past.");
    if (typeof vault.availableBalance === "bigint" && amount > vault.availableBalance) throw new Error("Available treasury capital does not cover this commitment.");
    vaultTx.writeVault({ functionName: "createCommitment", args: [recipient, amount, intervalValue, due] });
  });

  const execute = (id: bigint) => runFormAction(() => {
    if (!connected || !correctNetwork || !vaultReady) throw new Error("Discover a vault on Arbitrum Sepolia to execute.");
    vaultTx.writeVault({ functionName: "executeCommitment", args: [id] });
  });

  const cancel = (id: bigint) => runFormAction(() => {
    if (!controllerActive) throw new Error("Only the controller on Active mode can cancel commitments.");
    vaultTx.writeVault({ functionName: "cancelCommitment", args: [id] });
  });

  const submitWithdraw = () => runFormAction(() => {
    if (!controllerActive) throw new Error("Only the controller on Active mode can withdraw available capital.");
    if (decimals === undefined) throw new Error("USDG decimals are still loading.");
    const recipient = parseAddress(withdrawRecipient);
    const amount = parsePositiveTokenAmount(withdrawAmount, decimals);
    if (typeof vault.availableBalance !== "bigint" || amount > vault.availableBalance) throw new Error("Amount exceeds available USDG capital.");
    vaultTx.writeVault({ functionName: "withdrawAvailable", args: [recipient, amount] });
  });

  const checkIn = () => runFormAction(() => {
    if (!controller || (!active && !caution)) throw new Error("Check In requires the controller while the vault is Active or Caution.");
    vaultTx.writeVault({ functionName: "checkIn", args: [] });
  });

  const activate = () => runFormAction(() => {
    if (!connected || !correctNetwork || !vaultReady) throw new Error("Discover a vault on Arbitrum Sepolia to activate Continuity.");
    if (continuity) throw new Error("Continuity is already active.");
    if (currentTime === null || continuityEligibleAt === undefined || currentTime < continuityEligibleAt) throw new Error("Continuity is not yet eligible.");
    vaultTx.writeVault({ functionName: "activateContinuity", args: [] });
  });

  const requestRecovery = () => runFormAction(() => {
    if (!controllerContinuity) throw new Error("Only the controller in Continuity can request recovery.");
    vaultTx.writeVault({ functionName: "requestRecovery", args: [] });
  });

  const cancelRecovery = () => runFormAction(() => {
    if (!controllerContinuity || !recoveryRequested) throw new Error("Only the controller can cancel an active recovery request.");
    vaultTx.writeVault({ functionName: "cancelRecovery", args: [] });
  });

  const completeRecovery = () => runFormAction(() => {
    if (!controllerContinuity || !recoveryReady) throw new Error("Recovery delay has not elapsed.");
    vaultTx.writeVault({ functionName: "completeRecovery", args: [] });
  });

  const submitVaultCreation = () => runFormAction(() => discovery.createVault());

  const readState = !connected ? "Connect wallet to discover" : !correctNetwork ? "Switch network" : !vaultReady ? "Vault not selected" : vault.isPending ? "Reading…" : vault.isError ? "Read unavailable" : "Vault read OK";
  const displayMode = vaultReady ? operationalMode : undefined;
  const controllerLabel = !connected ? "Connect wallet to discover" : !correctNetwork ? "Wrong network" : !vaultReady ? discovery.status === "no-vault" ? "No vault created" : "Discovering vault" : controller ? "Controller" : "Not controller";
  const connectedWalletLabel = connected && wallet.address ? shortenAddress(wallet.address) : "Not connected";
  const ownerLabel = vaultReady && typeof vault.owner === "string" ? shortenAddress(vault.owner) : "Connect wallet to view";
  const continuityLabel = displayMode === undefined ? !connected ? "Connect wallet to view" : discovery.status === "no-vault" ? "No vault created" : "Vault context" : recoveryRequested ? "Recovery pending" : modeName(displayMode);
  const countdownLabel = !vaultReady ? "Vault timing" : displayMode === MODE_ACTIVE ? "Active window" : displayMode === MODE_CAUTION && currentTime === null ? "Timing" : displayMode === MODE_CAUTION && eligibilityRemaining !== undefined ? "Time until eligible" : displayMode === MODE_CAUTION ? "Activation" : recoveryRequested && currentTime === null ? "Timing" : recoveryRequested && !recoveryReady ? "Recovery delay" : recoveryRequested ? "Recovery" : "Continuity";
  const countdownValue = !vaultReady ? "Connect wallet to view" : displayMode === MODE_ACTIVE ? currentTime === null ? "Awaiting local clock" : activeWindowElapsed ? "Elapsed; awaiting refresh" : formatDuration(activeUntilRemaining) : displayMode === MODE_CAUTION && currentTime === null ? "Awaiting local clock" : displayMode === MODE_CAUTION && eligibilityRemaining !== undefined ? formatDuration(eligibilityRemaining) : displayMode === MODE_CAUTION ? "Continuity eligible" : recoveryRequested && currentTime === null ? "Awaiting local clock" : recoveryRequested && !recoveryReady && recoveryReadyAt !== undefined ? formatDuration(recoveryReadyAt - currentTime!) : recoveryRequested ? "Recovery ready" : "Active";
  const operationalStatus: OperationalStatus = displayMode === MODE_ACTIVE ? "active" : displayMode === MODE_CAUTION ? "caution" : displayMode === MODE_CONTINUITY ? "continuity" : "neutral";
  const heartbeatState = !connected ? "neutral" : displayMode === MODE_ACTIVE ? "active" : recoveryRequested ? "recovery" : displayMode === MODE_CAUTION ? "caution" : displayMode === MODE_CONTINUITY ? "continuity" : "neutral";
  const heartbeatLabel = heartbeatState === "active" ? "Active" : heartbeatState === "caution" ? "Overdue" : heartbeatState === "continuity" ? "Suspended" : heartbeatState === "recovery" ? "Recovery pending" : "Connect wallet to view";
  const stateCopy = !connected
    ? "Connect wallet to inspect the configured vault and its operational authority."
    : !correctNetwork
      ? "Switch to Arbitrum Sepolia to discover or create a wallet-specific vault."
      : !vaultReady
        ? "Create or rediscover an isolated vault before inspecting operational authority."
    : displayMode === MODE_ACTIVE
      ? "The controller heartbeat is current and normal authority is available."
      : displayMode === MODE_CAUTION
        ? "The heartbeat is overdue. Continuity has not been activated, and Check In can restore Active."
        : displayMode === MODE_CONTINUITY
          ? recoveryRequested
            ? "Recovery is pending. Discretionary authority remains suspended; protected operations remain executable."
            : "Discretionary authority is suspended. Protected operations remain executable."
          : "Reading contract state.";

  const openModal = (kind: "deposit" | "withdraw", origin: HTMLButtonElement) => {
    modalOriginRef.current = origin;
    setFormError(null);
    setActiveModal(kind);
  };

  const closeModal = useCallback(() => {
    if (transactionPending) return;
    const origin = modalOriginRef.current;
    modalOriginRef.current = null;
    setActiveModal(null);
    window.requestAnimationFrame(() => origin?.focus());
  }, [transactionPending]);

  useEffect(() => {
    if (!activeModal) return;

    const modal = modalRef.current;
    const focusable = () => Array.from(modal?.querySelectorAll<HTMLElement>("[data-modal-focusable]:not([disabled])") ?? []);
    focusable()[0]?.focus();
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        closeModal();
        return;
      }
      if (event.key !== "Tab") return;

      const elements = focusable();
      if (elements.length === 0) return;
      const first = elements[0]!;
      const last = elements[elements.length - 1]!;
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = previousOverflow;
    };
  }, [activeModal, closeModal]);

  return (
    <div className="application-container" id="overview">
      <section className="application-hero" aria-labelledby="page-title">
        <div className="application-hero__copy"><h1 className="editorial-heading application-hero__title" id="page-title">Financial continuity<br />for what matters.</h1><p className="application-hero__supporting">Treasury operations.<br />Explicit control.</p><div className="application-hero__meta"><span>DUREQO</span><span className="meta-rule" aria-hidden="true" /><span>Application</span></div></div>
        <div className="application-hero__architecture" aria-hidden="true"><div className="architecture-plane architecture-plane--back" /><div className="architecture-plane architecture-plane--front" /></div>
        <div className="application-hero__note"><TrackedLabel>Contract state.</TrackedLabel><TrackedLabel>Wallet authority.</TrackedLabel><Divider /><p>Every balance and operation below is read from the deployed vault and USDG contracts.</p></div>
      </section>

      <PaperCard className="operation-card paper-card--tactile vault-provisioning-card">
        <div className="surface-header"><div><h2>Vault context</h2><span className="surface-count">00</span></div><TrackedLabel>Onchain discovery</TrackedLabel></div>
        <p className="operation-copy">
          {!connected
            ? "Connect a wallet to discover a vault created by that wallet."
            : !correctNetwork
              ? "Switch to Arbitrum Sepolia to discover or create your vault."
              : discovery.status === "no-vault"
                ? "Create an isolated USDG continuity vault controlled initially by this wallet."
                : discovery.status === "ready"
                  ? `Using vault ${discovery.vaultAddress ? shortenAddress(discovery.vaultAddress) : "—"}. Current authority is read from owner().`
                  : discovery.status === "creation-pending"
                    ? "Vault creation is awaiting wallet confirmation or receipt confirmation."
                    : discovery.status === "creation-error"
                      ? "Vault creation did not complete. No vault context was changed."
                      : discovery.status === "discovery-error"
                        ? "Vault discovery failed. No fallback vault was selected."
                        : "Reading factory and vault state…"}
        </p>
        {connected && correctNetwork && discovery.status === "no-vault" ? <div className="form-actions"><Button variant="solid" disabled={discovery.isBusy} onClick={submitVaultCreation}>{discovery.isBusy ? "Creating…" : "Create DUREQO Vault"}</Button></div> : null}
        {discovery.errorMessage ? <p className="read-error" role="alert">Vault provisioning: {discovery.errorMessage}</p> : null}
        <TransactionNote label="Vault creation" phase={discovery.phase} error={discovery.errorMessage} />
      </PaperCard>

      <PaperCard className="continuity-card paper-card--tactile" id="activity">
        <div className="surface-header"><div><h2>Continuity Operations</h2><span className="surface-count">04</span></div>{vaultReady ? <StatusBadge status={operationalStatus} /> : <TrackedLabel>Connect wallet to view</TrackedLabel>}</div>
        <div className="continuity-card__timeline" aria-label="Continuity state progression"><span className={displayMode === MODE_ACTIVE ? "continuity-card__timeline-node continuity-card__timeline-node--current" : "continuity-card__timeline-node"}>Active</span><span className="continuity-card__timeline-rule" aria-hidden="true" /><span className={displayMode === MODE_CAUTION ? "continuity-card__timeline-node continuity-card__timeline-node--current" : "continuity-card__timeline-node"}>Caution</span><span className="continuity-card__timeline-rule" aria-hidden="true" /><span className={displayMode === MODE_CONTINUITY ? "continuity-card__timeline-node continuity-card__timeline-node--current" : "continuity-card__timeline-node"}>Continuity</span></div>
        <div className={`heartbeat-indicator heartbeat-indicator--${heartbeatState}`} role="status" aria-label={`Heartbeat activity: ${heartbeatLabel}`}>
          <span className="heartbeat-indicator__mark" aria-hidden="true" />
          <span className="heartbeat-indicator__copy"><TrackedLabel>Heartbeat activity</TrackedLabel><strong>{heartbeatLabel}</strong></span>
        </div>
        <div className="continuity-card__state"><strong>{continuityLabel}</strong><p>{stateCopy}</p></div>
        <div className="continuity-card__countdown"><TrackedLabel>{countdownLabel}</TrackedLabel><strong>{countdownValue}</strong></div>
        <div className="continuity-card__metrics">
          <div><TrackedLabel>Last heartbeat</TrackedLabel><span>{!vaultReady ? "Connect wallet to view" : typeof vault.lastHeartbeat === "bigint" ? displayDate(vault.lastHeartbeat) : "—"}</span></div>
          <div><TrackedLabel>Active until</TrackedLabel><span>{!vaultReady ? "Connect wallet to view" : activeUntil !== undefined ? displayDate(activeUntil) : "—"}</span></div>
          <div><TrackedLabel>Continuity eligible</TrackedLabel><span>{!vaultReady ? "Connect wallet to view" : continuityEligibleAt !== undefined ? displayDate(continuityEligibleAt) : "—"}</span></div>
          <div><TrackedLabel>Recovery ready</TrackedLabel><span>{!vaultReady ? "Connect wallet to view" : recoveryReadyAt === undefined ? "—" : displayDate(recoveryReadyAt)}</span></div>
        </div>
        <div className="continuity-card__metrics">
          <div><TrackedLabel>Heartbeat interval</TrackedLabel><span>{vaultReady ? formatDuration(typeof vault.heartbeatInterval === "bigint" ? vault.heartbeatInterval : undefined) : "Connect wallet to view"}</span></div>
          <div><TrackedLabel>Grace period</TrackedLabel><span>{vaultReady ? formatDuration(typeof vault.gracePeriod === "bigint" ? vault.gracePeriod : undefined) : "Connect wallet to view"}</span></div>
          <div><TrackedLabel>Recovery delay</TrackedLabel><span>{vaultReady ? formatDuration(recoveryDelay) : "Connect wallet to view"}</span></div>
          <div><TrackedLabel>Current time</TrackedLabel><span>{!vaultReady ? "Connect wallet to view" : currentTime === null ? "—" : displayDate(currentTime)}</span></div>
        </div>
        <div className="form-actions">
          {connected && controller && (active || caution) ? <Button variant="solid" disabled={transactionPending} onClick={checkIn}>{vaultTx.isBusy ? "Pending…" : "Check In"}</Button> : null}
          {connected && vaultReady && vault.continuityActivated === false ? <Button variant="quiet" disabled={transactionPending || currentTime === null || !correctNetwork || continuityEligibleAt === undefined || currentTime < continuityEligibleAt} onClick={activate}>{vaultTx.isBusy ? "Pending…" : "Activate Continuity"}</Button> : null}
          {controllerContinuity && !recoveryRequested ? <Button variant="quiet" disabled={transactionPending} onClick={requestRecovery}>{vaultTx.isBusy ? "Pending…" : "Request recovery"}</Button> : null}
          {controllerContinuity && recoveryRequested ? <Button variant="quiet" disabled={transactionPending} onClick={cancelRecovery}>{vaultTx.isBusy ? "Pending…" : "Cancel recovery"}</Button> : null}
          {controllerContinuity && recoveryRequested && recoveryReady ? <Button variant="solid" disabled={transactionPending} onClick={completeRecovery}>{vaultTx.isBusy ? "Pending…" : "Complete recovery"}</Button> : null}
        </div>
        {vaultReady && vault.continuityActivated === false ? <p className="operation-copy">Once eligible, Continuity may be activated by any connected account. Activation only triggers the already-authorized state; it grants no ownership, custody, or withdrawal authority.</p> : null}
        {recoveryRequested && !recoveryReady ? <p className="operation-copy">Recovery waiting: {currentTime === null ? "awaiting local clock" : recoveryReadyAt === undefined ? "reading delay" : `${formatDuration(recoveryReadyAt - currentTime)} remaining`}. The controller may cancel the request.</p> : null}
        <TransactionNote label="Continuity" phase={vaultTx.phase} error={vaultTx.errorMessage} />
      </PaperCard>

      <section className="operational-grid" aria-label="Treasury overview">
        <BalanceCard title="Treasury Balance" value={vault.vaultBalance} decimals={decimals} detail={readState} className="operational-card--balance paper-card--tactile paper-card--tactile-quiet" />
        <PaperCard className="operational-card paper-card--tactile paper-card--tactile-quiet"><div className="operational-card__header"><h2>Protection Coverage</h2><span className="card-menu">USDG</span></div><div className="live-value"><p>{displayUsd(vault.protectedBalance, decimals)}</p><small>Protected balance</small></div><Divider /><div className="card-footnote"><span>Available</span><strong>{displayUsd(vault.availableBalance, decimals)}</strong></div><div className="card-footnote"><span>Funded</span><strong>{typeof vault.isFunded === "boolean" ? vault.isFunded ? "Yes" : "No" : "—"}</strong></div></PaperCard>
        <PaperCard className="operational-card operational-card--controller paper-card--tactile paper-card--tactile-quiet"><div className="operational-card__header"><h2>Controller Status</h2><TrackedLabel>Identity / authority</TrackedLabel></div><div className="controller-state"><strong>{controllerLabel}</strong></div><Divider /><div className="controller-meta"><span>Connected wallet</span><strong className="mono-value">{connectedWalletLabel}</strong></div><div className="controller-meta"><span>Vault controller</span><strong className="mono-value">{ownerLabel}</strong></div><div className="controller-meta"><span>Operational mode</span>{vaultReady ? <StatusBadge status={operationalStatus} /> : <strong>Connect wallet to view</strong>}</div></PaperCard>
      </section>
      {vault.isError ? <p className="read-error" role="alert">Vault reads unavailable: {errorText(vault.error)}</p> : null}

      <section className="phase12-operations" aria-label="Treasury operations">
        <PaperCard id="deposit" className="operation-card paper-card--tactile"><div className="surface-header"><div><h2>Deposit USDG</h2><span className="surface-count">01</span></div><TrackedLabel>Exact approval</TrackedLabel></div><div className="paper-card__summary"><div><TrackedLabel>Connected wallet USDG</TrackedLabel><strong>{displayUsd(token.balance, decimals)}</strong></div><div><TrackedLabel>Current allowance</TrackedLabel><strong>{displayUsd(token.allowance, decimals)}</strong></div></div><p className="operation-copy">Approve only the requested amount, then explicitly submit the deposit. Approval never submits a deposit automatically.</p><div className="form-actions"><Button variant="solid" disabled={!connected || !correctNetwork || !vaultReady} onClick={(event) => openModal("deposit", event.currentTarget)}>Deposit USDG</Button></div></PaperCard>
        <PaperCard id="withdraw" className="operation-card paper-card--tactile"><div className="surface-header"><div><h2>Withdraw Available</h2><span className="surface-count">02</span></div><ControllerModeLabel status={operationalStatus} label={controllerLabel} connected={vaultReady} /></div><div className="paper-card__summary"><div><TrackedLabel>Available capital</TrackedLabel><strong>{displayUsd(vault.availableBalance, decimals)}</strong></div><div><TrackedLabel>Identity / role</TrackedLabel><strong>{controllerLabel}</strong></div><div><TrackedLabel>Operational mode</TrackedLabel>{vaultReady ? <StatusBadge status={operationalStatus} /> : <strong>Connect wallet to view</strong>}</div></div><p className="operation-copy">Only unprotected available capital can be withdrawn. Protected balance cannot be withdrawn.</p><div className="form-actions"><Button variant="solid" disabled={!connected || !correctNetwork || !vaultReady} onClick={(event) => openModal("withdraw", event.currentTarget)}>Withdraw Available</Button></div></PaperCard>
        <PaperCard id="create" className="operation-card operation-card--wide paper-card--tactile"><div className="surface-header"><div><h2>Create Commitment</h2><span className="surface-count">03</span></div><ControllerModeLabel status={operationalStatus} label={controllerLabel} connected={vaultReady} /></div><p className="operation-copy">Commit a stored recipient and amount against currently available treasury capital. The vault remains authoritative.</p><div className="form-row form-row--four"><label>Recipient<input value={createRecipient} onChange={(event) => setCreateRecipient(event.target.value)} placeholder="0x…" /></label><label>Amount<input inputMode="decimal" value={createAmount} onChange={(event) => setCreateAmount(event.target.value)} placeholder="0.00" /></label><label>Type<select value={commitmentType} onChange={(event) => setCommitmentType(event.target.value as "one-time" | "recurring")}><option value="one-time">One-time</option><option value="recurring">Recurring</option></select></label><label>{commitmentType === "recurring" ? "Interval (seconds)" : "Interval"}<input disabled={commitmentType === "one-time"} inputMode="numeric" value={commitmentType === "one-time" ? "0" : interval} onChange={(event) => setInterval(event.target.value)} placeholder="0" /></label></div><div className="form-row"><label>First due<input type="datetime-local" value={firstDue} onChange={(event) => setFirstDue(event.target.value)} /></label></div><div className="form-actions"><Button variant="solid" disabled={!controllerActive || transactionPending} onClick={submitCreate}>{vaultTx.isBusy ? vaultTx.isConfirming ? "Confirming…" : "Creating…" : "Create commitment"}</Button></div></PaperCard>
      </section>

      {formError && !activeModal ? <p className="read-error" role="alert">{formError}</p> : null}
      <section className="commitments-surface paper-card" id="commitments" aria-label="Protected commitments"><div className="surface-header"><div><h2>Protected Commitments</h2><span className="surface-count">{displayInteger(vault.commitmentCount)}</span></div><TrackedLabel>Onchain state</TrackedLabel></div>{!vaultReady ? <div className="empty-surface"><TrackedLabel>Vault context required</TrackedLabel><p>Discover or create a vault before reading commitments.</p></div> : commitments.isPending ? <div className="empty-surface"><TrackedLabel>Reading commitments…</TrackedLabel></div> : commitments.isError ? <div className="empty-surface"><TrackedLabel>Commitments unavailable</TrackedLabel><p>{errorText(commitments.error)}</p></div> : commitments.tooMany ? <div className="empty-surface"><TrackedLabel>Commitment list exceeds display limit</TrackedLabel><p>The onchain count is {displayInteger(vault.commitmentCount)}. No partial list is shown.</p></div> : commitments.commitments.length === 0 ? <div className="empty-surface"><TrackedLabel>No commitments available</TrackedLabel><p>Zero commitments is a valid vault state.</p></div> : <div className="commitment-list">{commitments.commitments.map((commitment) => <CommitmentRow key={commitment.id.toString()} commitment={commitment} decimals={decimals} currentTime={currentTime} canCancel={Boolean(controllerActive)} canExecute={Boolean(connected && correctNetwork && vaultReady)} pending={vaultTx.isBusy} onCancel={cancel} onExecute={execute} />)}</div>}</section>
      <section className="application-state-strip" aria-label="Connected wallet balance"><div><TrackedLabel>Connected wallet USDG</TrackedLabel><strong>{displayUsd(token.balance, decimals)}</strong></div><div><TrackedLabel>Vault funding</TrackedLabel><strong>{typeof vault.isFunded === "boolean" ? vault.isFunded ? "Funded" : "Not funded" : "Reading…"}</strong></div><div><TrackedLabel>Execution</TrackedLabel><strong>{connected && correctNetwork ? "Wallet ready" : "Connect on Arbitrum Sepolia"}</strong></div></section>

      {activeModal ? (
        <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget && !transactionPending) closeModal(); }}>
          <section ref={modalRef} className="paper-modal" role="dialog" aria-modal="true" aria-labelledby={`${activeModal}-modal-title`} onMouseDown={(event) => event.stopPropagation()}>
            {activeModal === "deposit" ? (
              <>
                <div className="paper-modal__header"><div><TrackedLabel>Operation 01</TrackedLabel><h2 id="deposit-modal-title">Deposit USDG</h2></div><button className="paper-modal__close" type="button" data-modal-focusable aria-label="Close Deposit USDG" disabled={transactionPending} onClick={closeModal}>×</button></div>
                <div className="paper-card__summary"><div><TrackedLabel>Connected wallet USDG</TrackedLabel><strong>{displayUsd(token.balance, decimals)}</strong></div><div><TrackedLabel>Current allowance</TrackedLabel><strong>{displayUsd(token.allowance, decimals)}</strong></div></div>
                <p className="operation-copy">Approve only the exact requested amount. Approval never submits a deposit automatically; the final deposit remains an explicit separate action.</p>
                <div className="form-row"><label>Amount<input data-modal-focusable inputMode="decimal" value={depositAmount} onChange={(event) => setDepositAmount(event.target.value)} placeholder={decimals === undefined ? "Reading decimals…" : "0.00"} /></label></div>
                <div className="form-actions">{depositNeedsApproval ? <Button variant="solid" data-modal-focusable disabled={transactionPending || !connected || !correctNetwork} onClick={submitDepositApproval}>{approvalTx.isBusy ? approvalTx.isConfirming ? "Confirming…" : "Approving…" : "Approve USDG"}</Button> : <Button variant="solid" data-modal-focusable disabled={!depositReady} onClick={submitDeposit}>{vaultTx.isBusy ? vaultTx.isConfirming ? "Confirming…" : "Depositing…" : "Deposit USDG"}</Button>}</div>
                {formError ? <p className="read-error" role="alert">{formError}</p> : null}
                {approvalTx.isConfirmed ? <p className="transaction-note">Approval confirmed. Deposit remains a separate action.</p> : null}<TransactionNote label="Approval" phase={approvalTx.phase} error={approvalTx.errorMessage} /><TransactionNote label="Deposit" phase={vaultTx.phase} error={vaultTx.errorMessage} />
              </>
            ) : (
              <>
                <div className="paper-modal__header"><div><TrackedLabel>Operation 02</TrackedLabel><h2 id="withdraw-modal-title">Withdraw Available</h2></div><button className="paper-modal__close" type="button" data-modal-focusable aria-label="Close Withdraw Available" disabled={transactionPending} onClick={closeModal}>×</button></div>
                <div className="paper-card__summary"><div><TrackedLabel>Available capital</TrackedLabel><strong>{displayUsd(vault.availableBalance, decimals)}</strong></div><div><TrackedLabel>Identity / role</TrackedLabel><strong>{controllerLabel}</strong></div><div><TrackedLabel>Operational mode</TrackedLabel>{vaultReady ? <StatusBadge status={operationalStatus} /> : <strong>Connect wallet to view</strong>}</div></div>
                <p className="operation-copy">Only unprotected available capital can be withdrawn. Protected balance cannot be withdrawn.</p>
                <div className="form-row"><label>Recipient<input data-modal-focusable value={withdrawRecipient} onChange={(event) => setWithdrawRecipient(event.target.value)} placeholder="0x…" /></label><label>Amount<input data-modal-focusable inputMode="decimal" value={withdrawAmount} onChange={(event) => setWithdrawAmount(event.target.value)} placeholder="0.00" /></label></div>
                <div className="form-actions"><Button variant="solid" data-modal-focusable disabled={!controllerActive || transactionPending} onClick={submitWithdraw}>{vaultTx.isBusy ? vaultTx.isConfirming ? "Confirming…" : "Withdrawing…" : "Withdraw Available"}</Button></div>
                {formError ? <p className="read-error" role="alert">{formError}</p> : null}<TransactionNote label="Withdrawal" phase={vaultTx.phase} error={vaultTx.errorMessage} />
              </>
            )}
          </section>
        </div>
      ) : null}
    </div>
  );
}
