import type { ReactNode } from "react";
import Link from "next/link";
import { Button, TrackedLabel } from "./foundation";

const navigationItems = [
  { label: "Overview", href: "#overview", current: true },
  { label: "Treasury", href: "#treasury" },
  { label: "Commitments", href: "#commitments" },
  { label: "Activity", href: "#activity" },
];

export function TopNavigation() {
  return (
    <header className="top-navigation">
      <div className="top-navigation__inner">
        <Link className="brand-lockup" href="#overview" aria-label="DUREQO overview">
          <span className="brand-lockup__name">DUREQO</span>
        </Link>

        <nav className="primary-navigation" aria-label="Primary navigation">
          {navigationItems.map((item) => (
            <Link
              className={`primary-navigation__link${item.current ? " primary-navigation__link--current" : ""}`}
              href={item.href}
              key={item.label}
              aria-current={item.current ? "page" : undefined}
            >
              {item.label}
            </Link>
          ))}
          <span
            className="primary-navigation__disabled"
            aria-disabled="true"
            title="Agents is not available in this phase"
          >
            Agents
          </span>
        </nav>

        <div className="top-navigation__controls">
          <span className="network-badge">
            <span className="network-badge__dot" aria-hidden="true" />
            Arbitrum Sepolia
          </span>
          <div className="account-shell">
            <TrackedLabel>Account</TrackedLabel>
            <Button variant="quiet" disabled aria-label="Wallet connection is not available in Phase 10">
              Not connected
            </Button>
          </div>
        </div>
      </div>
    </header>
  );
}

export function AppShell({ children }: { children: ReactNode }) {
  return (
    <div className="app-shell">
      <TopNavigation />
      <main>{children}</main>
      <footer className="app-footer">
        <span>DUREQO / Financial Continuity Infrastructure</span>
        <span>Foundation preview · no contract data connected</span>
      </footer>
    </div>
  );
}
