import type { ButtonHTMLAttributes, HTMLAttributes, ReactNode } from "react";

type Status = "active" | "caution" | "continuity" | "neutral";

const statusLabels: Record<Status, string> = {
  active: "Active",
  caution: "Caution",
  continuity: "Continuity",
  neutral: "Neutral",
};

export function TrackedLabel({ children }: { children: ReactNode }) {
  return <span className="tracked-label">{children}</span>;
}

export function EditorialHeading({
  children,
  as: Tag = "h2",
  className = "",
}: {
  children: ReactNode;
  as?: "h1" | "h2" | "h3";
  className?: string;
}) {
  return <Tag className={`editorial-heading ${className}`}>{children}</Tag>;
}

export function PaperCard({
  children,
  className = "",
  layered = false,
  ...props
}: HTMLAttributes<HTMLElement> & { layered?: boolean }) {
  return (
    <section className={`paper-card${layered ? " paper-card--layered" : ""} ${className}`} {...props}>
      {children}
    </section>
  );
}

export function StatusBadge({ status }: { status: Status }) {
  return (
    <span className={`status-badge status-badge--${status}`}>
      <span className="status-badge__dot" aria-hidden="true" />
      {statusLabels[status]}
    </span>
  );
}

export function Button({
  children,
  variant = "solid",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "solid" | "quiet" }) {
  return (
    <button className={`button button--${variant}`} {...props}>
      {children}
    </button>
  );
}

export function Divider({ className = "" }: { className?: string }) {
  return <div className={`divider ${className}`} role="presentation" />;
}

export function MetricDisplay({
  label,
  value,
  detail,
}: {
  label: string;
  value: string;
  detail?: string;
}) {
  return (
    <div className="metric-display">
      <TrackedLabel>{label}</TrackedLabel>
      <p className="metric-display__value">{value}</p>
      {detail ? <p className="metric-display__detail">{detail}</p> : null}
    </div>
  );
}

export function SectionHeading({
  children,
  detail,
}: {
  children: ReactNode;
  detail?: string;
}) {
  return (
    <div className="section-heading">
      <EditorialHeading as="h2">{children}</EditorialHeading>
      {detail ? <p className="section-heading__detail">{detail}</p> : null}
    </div>
  );
}
