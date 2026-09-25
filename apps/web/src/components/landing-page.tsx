import Image from "next/image";
import Link from "next/link";

const states = [
  {
    label: "Active",
    title: "Full authority",
    copy: "The controller heartbeat is current and discretionary treasury operations remain available.",
  },
  {
    label: "Caution",
    title: "Authority contracts",
    copy: "The heartbeat has expired. Continuity has not been activated; a controller Check In can restore Active.",
  },
  {
    label: "Continuity",
    title: "Protected operations persist",
    copy: "After eligibility and explicit activation, discretionary authority is suspended while due protected commitments remain executable.",
  },
  {
    label: "Recovery",
    title: "A controlled return",
    copy: "The controller begins a delayed recovery. Restrictions remain until recovery completes successfully.",
  },
];

export function LandingPage() {
  return (
    <div className="landing-page">
      <header className="landing-navigation">
        <Link className="landing-brand" href="/" aria-label="DUREQO home">
          <span>DUREQO</span>
        </Link>
        <nav className="landing-navigation__links" aria-label="Landing navigation">
          <a href="#mechanism">How it works</a>
          <a href="#continuity">Continuity</a>
          <Link href="/app">Application</Link>
        </nav>
        <span className="landing-category">Financial Continuity Infrastructure</span>
      </header>

      <main>
        <section className="landing-hero" aria-labelledby="landing-title">
          <div className="landing-hero__copy">
            <span className="landing-index">01 <span aria-hidden="true" /></span>
            <p className="landing-eyebrow">Financial continuity infrastructure</p>
            <h1 id="landing-title">Keep what matters <em>in motion.</em></h1>
            <p className="landing-hero__lede">DUREQO is financial continuity infrastructure for organizations whose critical operations should not depend on one controller remaining continuously available.</p>
            <div className="landing-hero__actions">
              <Link className="landing-button landing-button--solid" href="/app">Enter Application <span aria-hidden="true">↗</span></Link>
              <a className="landing-text-link" href="#mechanism">How it works <span aria-hidden="true">↓</span></a>
            </div>
            <p className="landing-hero__footnote">Pre-authorize what must survive without pre-authorizing unrestricted access.</p>
          </div>

          <div className="landing-hero__architecture" aria-hidden="true">
            <Image className="landing-hero__architecture-image" src="/assets/approved/DUREQO2.png" alt="" fill priority sizes="(max-width: 760px) 100vw, 56vw" />
            <div className="landing-hero__architecture-scrim" />
            <span className="landing-hero__architecture-note">People / operations / continuity</span>
          </div>

          <aside className="landing-identity-card" aria-label="DUREQO identity">
            <div className="landing-identity-card__topline"><span>02</span><span>Arbitrum Sepolia · MVP</span></div>
            <div className="landing-identity-card__logo">
              <Image src="/assets/approved/DUREQOLOGO.png" alt="DUREQO — Financial Continuity Infrastructure" fill sizes="180px" />
            </div>
            <div className="landing-identity-card__rule" />
            <p>Pre-authorized commitments for a more resilient tomorrow.</p>
            <span className="landing-identity-card__caption">The contract remains the authority.</span>
          </aside>
        </section>

        <section className="landing-problem" id="mechanism" aria-labelledby="problem-title">
          <div className="landing-section-index">03 <span aria-hidden="true" /></div>
          <div>
            <h2 id="problem-title">Critical finance should not pause with one person.</h2>
            <p>Organizations can define what must continue before continuity is needed: a treasury vault, a recipient, an amount, and a due schedule. Authority contracts only when the onchain state says it should.</p>
          </div>
          <div className="landing-problem__quote">People fail.<br />Critical finance<br /><em>continues.</em></div>
        </section>

        <section className="landing-mechanism" id="continuity" aria-labelledby="continuity-title">
          <div className="landing-section-heading">
            <p className="landing-eyebrow">The continuity path</p>
            <h2 id="continuity-title">A measured contraction of authority.</h2>
            <p>Continuity is never automatic. It is eligible after the heartbeat and grace thresholds, then explicitly activated by any connected account.</p>
          </div>
          <div className="landing-state-sequence">
            {states.map((state, index) => (
              <div className="landing-state" key={state.label}>
                <div className="landing-state__header"><span>0{index + 1}</span><strong>{state.label}</strong></div>
                <h3>{state.title}</h3>
                <p>{state.copy}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="landing-principle" aria-labelledby="principle-title">
          <div className="landing-principle__mark" aria-hidden="true">D</div>
          <div>
            <p className="landing-eyebrow">The principle</p>
            <h2 id="principle-title">Pre-authorize what must survive without pre-authorizing unrestricted access.</h2>
          </div>
          <Link className="landing-button landing-button--quiet" href="/app">Enter Application <span aria-hidden="true">↗</span></Link>
        </section>
      </main>

      <footer className="landing-footer">
        <span>DUREQO / Financial Continuity Infrastructure</span>
        <span>Arbitrum Sepolia · Current MVP</span>
      </footer>
    </div>
  );
}
