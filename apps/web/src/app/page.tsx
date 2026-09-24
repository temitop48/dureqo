import type { ReactNode } from "react";
import { AppShell } from "@/components/navigation";
import { Button, Divider, PaperCard, StatusBadge, TrackedLabel } from "@/components/foundation";

function UnavailableValue({ detail }: { detail: string }) {
  return (
    <div className="unavailable-value">
      <p className="unavailable-value__mark">—</p>
      <p className="unavailable-value__detail">{detail}</p>
    </div>
  );
}

function OperationalCard({
  title,
  children,
  className = "",
  id,
}: {
  title: string;
  children: ReactNode;
  className?: string;
  id?: string;
}) {
  return (
    <PaperCard className={`operational-card ${className}`} id={id}>
      <div className="operational-card__header">
        <h2>{title}</h2>
        <span className="card-menu" aria-hidden="true">•••</span>
      </div>
      {children}
    </PaperCard>
  );
}

function QuickAction({ label, detail }: { label: string; detail: string }) {
  return (
    <button className="quick-action" type="button" disabled aria-label={`${label}: unavailable in Phase 10`}>
      <span className="quick-action__symbol" aria-hidden="true">+</span>
      <span className="quick-action__copy">
        <strong>{label}</strong>
        <small>{detail}</small>
      </span>
      <span className="quick-action__arrow" aria-hidden="true">↗</span>
    </button>
  );
}

export default function Home() {
  return (
    <AppShell>
      <div className="application-container" id="overview">
        <section className="application-hero" aria-labelledby="page-title">
          <div className="application-hero__copy">
            <h1 className="editorial-heading application-hero__title" id="page-title">
              Financial continuity
              <br />
              for what matters.
            </h1>
            <p className="application-hero__supporting">
              Pre-authorize essential operations.
              <br />
              Maintain control.
            </p>
            <div className="application-hero__meta">
              <span>DUREQO</span>
              <span className="meta-rule" aria-hidden="true" />
              <span>Foundation preview</span>
            </div>
          </div>
          <div className="application-hero__architecture" aria-label="Architectural image slot reserved for approved production imagery">
            <div className="architecture-plane architecture-plane--back" aria-hidden="true" />
            <div className="architecture-plane architecture-plane--front" aria-hidden="true" />
            <TrackedLabel>Approved architectural asset slot</TrackedLabel>
          </div>
          <div className="application-hero__note">
            <TrackedLabel>People fail.</TrackedLabel>
            <TrackedLabel>Critical finance continues.</TrackedLabel>
            <Divider />
            <p>Operational surfaces remain composed when attention is elsewhere.</p>
          </div>
        </section>

        <section className="operational-grid" aria-label="Treasury overview">
          <OperationalCard title="Treasury Balance" className="operational-card--balance" id="treasury">
            <UnavailableValue detail="USDG balance unavailable" />
            <Divider />
            <div className="card-footnote">
              <span>Connection</span>
              <strong>Connect in Phase 11</strong>
            </div>
          </OperationalCard>

          <OperationalCard title="Protection Coverage">
            <UnavailableValue detail="Coverage unavailable" />
            <div className="coverage-placeholder" aria-hidden="true"><span /></div>
            <p className="operational-card__detail">Protected and available balances appear after contract connection.</p>
          </OperationalCard>

          <OperationalCard title="Controller Status" className="operational-card--controller">
            <div className="controller-state">
              <StatusBadge status="neutral" />
              <strong>Not connected</strong>
            </div>
            <Divider />
            <div className="controller-meta">
              <span>Heartbeat</span>
              <strong>Unavailable</strong>
            </div>
            <Button variant="solid" disabled>Check In unavailable</Button>
          </OperationalCard>
        </section>

        <section className="lower-application-grid" aria-label="Protected operations">
          <PaperCard className="commitments-surface" id="commitments">
            <div className="surface-header">
              <div>
                <h2>Protected Commitments</h2>
                <span className="surface-count">—</span>
              </div>
              <Button variant="quiet" disabled>Add Commitment</Button>
            </div>
            <div className="empty-surface">
              <TrackedLabel>No commitments available</TrackedLabel>
              <p>Connect in Phase 11 to view protected operations.</p>
            </div>
          </PaperCard>

          <PaperCard className="quick-actions-surface">
            <div className="surface-header"><h2>Quick Actions</h2></div>
            <div className="quick-actions-grid">
              <QuickAction label="Deposit USDG" detail="Unavailable" />
              <QuickAction label="Withdraw Available" detail="Unavailable" />
              <QuickAction label="View Activity" detail="Unavailable" />
              <QuickAction label="Treasury Settings" detail="Immutable in V1" />
            </div>
          </PaperCard>
        </section>
      </div>
    </AppShell>
  );
}
