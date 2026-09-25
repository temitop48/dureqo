"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { formatUnits, type Address } from "viem";
import { useAccount } from "wagmi";
import { Button, Divider, PaperCard, StatusBadge, TrackedLabel } from "./foundation";
import { useConnectedUsdGReads, useCommitmentReads, useVaultReads, type Commitment } from "@/lib/web3/reads";
import { ARBITRUM_SEPOLIA_CHAIN_ID } from "@/lib/web3/config";
import { normalizeWeb3Error } from "@/lib/web3/errors";
import { useUsdGApproval, useVaultTransaction } from "@/lib/web3/transaction";
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
  return new Date(Number(value) * 1000).toLocaleString();
}

function modeName(mode: number | undefined) {
  if (mode === MODE_ACTIVE) return "Active";
  if (mode === MODE_CAUTION) return "Caution";
  if (mode === MODE_CONTINUITY) return "Continuity";
  return "Reading…";
}

function isSameAddress(left: Address | undefined, right: unknown) {
  return Boolean(left && typeof right === "string" && left.toLowerCase() === right.toLowerCase());
}

function errorText(error: unknown) {
  return normalizeWeb3Error(error);
}

function useRefreshReads() {
  const vault = useVaultReads();
  const wallet = useAccount();
  const token = useConnectedUsdGReads(wallet.address);
  const commitments = useCommitmentReads(vault.commitmentCount);
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
  return (
    <p className={`transaction-note${error ? " transaction-note--error" : ""}`} role={error ? "alert" : undefined}>
      {error ? `${label}: ${error}` : `${label}: ${phase.replaceAll("-", " ")}`}
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

function CommitmentRow({ commitment, decimals, currentTime, canCancel, canExecute, pending, onCancel, onExecute }: { commitment: { id: bigint } & Commitment; decimals: number | undefined; currentTime: bigint; canCancel: boolean; canExecute: boolean; pending: boolean; onCancel: (id: bigint) => void; onExecute: (id: bigint) => void }) {
  const due = commitment.active && currentTime >= commitment.nextDue;
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
  const { vault, wallet, token, commitments, refresh } = useRefreshReads();
  const vaultTx = useVaultTransaction();
  const approvalTx = useUsdGApproval();
  const [depositAmount, setDepositAmount] = useState("");
  const [createRecipient, setCreateRecipient] = useState("");
  const [createAmount, setCreateAmount] = useState("");
  const [commitmentType, setCommitmentType] = useState<"one-time" | "recurring">("one-time");
  const [interval, setInterval] = useState("");
  const [firstDue, setFirstDue] = useState("");
  const [withdrawRecipient, setWithdrawRecipient] = useState("");
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [formError, setFormError] = useState<string | null>(null);
  const lastConfirmedHash = useRef<string | undefined>(undefined);
  const [currentTime, setCurrentTime] = useState(() => BigInt(Math.floor(Date.now() / 1000)));
  const decimals = typeof vault.decimals === "number" ? vault.decimals : undefined;
  const connected = wallet.isConnected;
  const correctNetwork = connected && wallet.chainId === ARBITRUM_SEPOLIA_CHAIN_ID;
  const active = vault.mode === MODE_ACTIVE;
  const controller = correctNetwork && isSameAddress(wallet.address, vault.owner);
  const controllerActive = controller && active;
  const transactionPending = vaultTx.isBusy || approvalTx.isBusy;

  useEffect(() => {
    const clock = window.setInterval(() => {
      setCurrentTime(BigInt(Math.floor(Date.now() / 1000)));
    }, 15_000);
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
    if (!connected || !correctNetwork) throw new Error("Connect a wallet on Arbitrum Sepolia first.");
    if (typeof token.balance !== "bigint" || token.balance < parsedDeposit) throw new Error("Wallet USDG balance is insufficient.");
    approvalTx.approve(parsedDeposit);
  });

  const submitDeposit = () => runFormAction(() => {
    if (parsedDeposit === undefined) throw new Error("Enter a valid USDG amount.");
    if (!depositReady) throw new Error("Approve the exact deposit amount before depositing.");
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
    if (!connected || !correctNetwork) throw new Error("Connect a wallet on Arbitrum Sepolia to execute.");
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

  const readState = vault.isPending ? "Reading…" : vault.isError ? "Read unavailable" : "Vault read OK";
  const controllerLabel = !connected ? "Not connected" : !correctNetwork ? "Wrong network" : vault.isPending ? "Reading…" : controller ? "Controller" : "Connected / Not controller";
  const controllerStatus: "active" | "caution" | "neutral" = !connected || !correctNetwork ? "neutral" : controller ? "active" : "caution";

  return (
    <div className="application-container" id="overview">
      <section className="application-hero" aria-labelledby="page-title">
        <div className="application-hero__copy"><h1 className="editorial-heading application-hero__title" id="page-title">Financial continuity<br />for what matters.</h1><p className="application-hero__supporting">Treasury operations.<br />Explicit control.</p><div className="application-hero__meta"><span>DUREQO</span><span className="meta-rule" aria-hidden="true" /><span>Application</span></div></div>
        <div className="application-hero__architecture" aria-hidden="true"><div className="architecture-plane architecture-plane--back" /><div className="architecture-plane architecture-plane--front" /></div>
        <div className="application-hero__note"><TrackedLabel>Contract state.</TrackedLabel><TrackedLabel>Wallet authority.</TrackedLabel><Divider /><p>Every balance and operation below is read from the deployed vault and USDG contracts.</p></div>
      </section>

      <section className="operational-grid" aria-label="Treasury overview">
        <BalanceCard title="Treasury Balance" value={vault.vaultBalance} decimals={decimals} detail={readState} className="operational-card--balance" />
        <PaperCard className="operational-card"><div className="operational-card__header"><h2>Protection Coverage</h2><span className="card-menu">USDG</span></div><div className="live-value"><p>{displayUsd(vault.protectedBalance, decimals)}</p><small>Protected balance</small></div><Divider /><div className="card-footnote"><span>Available</span><strong>{displayUsd(vault.availableBalance, decimals)}</strong></div><div className="card-footnote"><span>Funded</span><strong>{typeof vault.isFunded === "boolean" ? vault.isFunded ? "Yes" : "No" : "—"}</strong></div></PaperCard>
        <PaperCard className="operational-card operational-card--controller"><div className="operational-card__header"><h2>Controller Status</h2><StatusBadge status={controllerStatus} /></div><div className="controller-state"><strong>{controllerLabel}</strong></div><Divider /><div className="controller-meta"><span>Mode</span><strong>{modeName(vault.mode)}</strong></div><div className="controller-meta"><span>Owner</span><strong className="mono-value">{typeof vault.owner === "string" ? vault.owner : "—"}</strong></div></PaperCard>
      </section>
      {vault.isError ? <p className="read-error" role="alert">Vault reads unavailable: {errorText(vault.error)}</p> : null}

      <section className="phase12-operations" aria-label="Treasury operations">
        <PaperCard id="deposit" className="operation-card"><div className="surface-header"><div><h2>Deposit USDG</h2><span className="surface-count">01</span></div><TrackedLabel>Exact amount</TrackedLabel></div><p className="operation-copy">Approve only the requested amount, then explicitly submit the deposit. Approval never submits a deposit automatically.</p><div className="wallet-balance-line"><span>Connected wallet</span><strong>{displayUsd(token.balance, decimals)}</strong></div><div className="form-row"><label>Amount<input inputMode="decimal" value={depositAmount} onChange={(event) => setDepositAmount(event.target.value)} placeholder={decimals === undefined ? "Reading decimals…" : "0.00"} /></label></div><div className="form-actions">{depositNeedsApproval ? <Button variant="solid" disabled={transactionPending || !connected || !correctNetwork} onClick={submitDepositApproval}>{approvalTx.isBusy ? approvalTx.isConfirming ? "Confirming…" : "Approving…" : "Approve USDG"}</Button> : <Button variant="solid" disabled={!depositReady} onClick={submitDeposit}>{vaultTx.isBusy ? vaultTx.isConfirming ? "Confirming…" : "Depositing…" : "Deposit USDG"}</Button>}</div>{approvalTx.isConfirmed ? <p className="transaction-note">Approval confirmed. Deposit remains a separate action.</p> : null}<TransactionNote label="Approval" phase={approvalTx.phase} error={approvalTx.errorMessage} /><TransactionNote label="Deposit" phase={vaultTx.phase} error={vaultTx.errorMessage} /></PaperCard>
        <PaperCard id="withdraw" className="operation-card"><div className="surface-header"><div><h2>Withdraw Available</h2><span className="surface-count">02</span></div><TrackedLabel>Controller · Active</TrackedLabel></div><p className="operation-copy">Withdraws only unprotected capital. Protected balance is never discretionary withdrawal capacity.</p><div className="wallet-balance-line"><span>Available capital</span><strong>{displayUsd(vault.availableBalance, decimals)}</strong></div><div className="form-row"><label>Recipient<input value={withdrawRecipient} onChange={(event) => setWithdrawRecipient(event.target.value)} placeholder="0x…" /></label><label>Amount<input inputMode="decimal" value={withdrawAmount} onChange={(event) => setWithdrawAmount(event.target.value)} placeholder="0.00" /></label></div><div className="form-actions"><Button variant="solid" disabled={!controllerActive || transactionPending} onClick={submitWithdraw}>{vaultTx.isBusy ? vaultTx.isConfirming ? "Confirming…" : "Withdrawing…" : "Withdraw available"}</Button></div></PaperCard>
        <PaperCard id="create" className="operation-card operation-card--wide"><div className="surface-header"><div><h2>Create Commitment</h2><span className="surface-count">03</span></div><TrackedLabel>Controller · Active</TrackedLabel></div><p className="operation-copy">Commit a stored recipient and amount against currently available treasury capital. The vault remains authoritative.</p><div className="form-row form-row--four"><label>Recipient<input value={createRecipient} onChange={(event) => setCreateRecipient(event.target.value)} placeholder="0x…" /></label><label>Amount<input inputMode="decimal" value={createAmount} onChange={(event) => setCreateAmount(event.target.value)} placeholder="0.00" /></label><label>Type<select value={commitmentType} onChange={(event) => setCommitmentType(event.target.value as "one-time" | "recurring")}><option value="one-time">One-time</option><option value="recurring">Recurring</option></select></label><label>{commitmentType === "recurring" ? "Interval (seconds)" : "Interval"}<input disabled={commitmentType === "one-time"} inputMode="numeric" value={commitmentType === "one-time" ? "0" : interval} onChange={(event) => setInterval(event.target.value)} placeholder="0" /></label></div><div className="form-row"><label>First due<input type="datetime-local" value={firstDue} onChange={(event) => setFirstDue(event.target.value)} /></label></div><div className="form-actions"><Button variant="solid" disabled={!controllerActive || transactionPending} onClick={submitCreate}>{vaultTx.isBusy ? vaultTx.isConfirming ? "Confirming…" : "Creating…" : "Create commitment"}</Button></div></PaperCard>
      </section>

      {formError ? <p className="read-error" role="alert">{formError}</p> : null}
      <section className="commitments-surface paper-card" id="commitments" aria-label="Protected commitments"><div className="surface-header"><div><h2>Protected Commitments</h2><span className="surface-count">{displayInteger(vault.commitmentCount)}</span></div><TrackedLabel>Onchain state</TrackedLabel></div>{commitments.isPending ? <div className="empty-surface"><TrackedLabel>Reading commitments…</TrackedLabel></div> : commitments.isError ? <div className="empty-surface"><TrackedLabel>Commitments unavailable</TrackedLabel><p>{errorText(commitments.error)}</p></div> : commitments.tooMany ? <div className="empty-surface"><TrackedLabel>Commitment list exceeds display limit</TrackedLabel><p>The onchain count is {displayInteger(vault.commitmentCount)}. No partial list is shown.</p></div> : commitments.commitments.length === 0 ? <div className="empty-surface"><TrackedLabel>No commitments available</TrackedLabel><p>Zero commitments is a valid vault state.</p></div> : <div className="commitment-list">{commitments.commitments.map((commitment) => <CommitmentRow key={commitment.id.toString()} commitment={commitment} decimals={decimals} currentTime={currentTime} canCancel={Boolean(controllerActive)} canExecute={Boolean(connected && correctNetwork)} pending={vaultTx.isBusy} onCancel={cancel} onExecute={execute} />)}</div>}</section>
      <section className="application-state-strip" aria-label="Connected wallet balance"><div><TrackedLabel>Connected wallet USDG</TrackedLabel><strong>{displayUsd(token.balance, decimals)}</strong></div><div><TrackedLabel>Vault funding</TrackedLabel><strong>{typeof vault.isFunded === "boolean" ? vault.isFunded ? "Funded" : "Not funded" : "Reading…"}</strong></div><div><TrackedLabel>Execution</TrackedLabel><strong>{connected && correctNetwork ? "Wallet ready" : "Connect on Arbitrum Sepolia"}</strong></div></section>
    </div>
  );
}
