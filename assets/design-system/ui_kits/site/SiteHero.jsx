// Hero — the only real surface on the Quixote marketing site.
// Mirrors site/src/pages/index.astro.

function QxSiteHero({ logoSrc, version = '1.0.0', dmgUrl = '#', githubUrl = 'https://github.com/c0/quixote' }) {
  return (
    <section style={{
      display: 'flex', flexDirection: 'column', alignItems: 'center',
      textAlign: 'center', gap: 14,
      fontFamily: QX_SITE.fontSans, color: QX_SITE.fg1,
    }}>
      <img src={logoSrc} alt="Quixote logo" style={{
        width: 'min(280px, 58vw)', height: 'auto', display: 'block',
        marginBottom: 10,
        filter: 'drop-shadow(0 18px 38px rgba(0, 0, 0, 0.4))',
      }} />
      <h1 style={{
        fontSize: 'clamp(2.8rem, 7vw, 4.4rem)',
        fontWeight: 700,
        letterSpacing: '-0.04em',
        lineHeight: 0.96,
        color: QX_SITE.fg1,
        margin: 0,
      }}>Data Quixote</h1>
      <p style={{
        fontSize: '1.05rem', color: QX_SITE.fg2, maxWidth: 460, margin: 0, lineHeight: 1.6,
      }}>Run multiple LLM prompts on any set of data. Iterate and refine.</p>
      <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'center', gap: 10, marginTop: 10 }}>
        <QxSiteButton variant="primary" href={dmgUrl} icon={<QxAppleGlyph />}>
          Download for macOS
        </QxSiteButton>
        <QxSiteButton variant="secondary" href={githubUrl}>GitHub</QxSiteButton>
      </div>
      <p style={{ fontSize: '0.82rem', color: QX_SITE.fg3, marginTop: 8 }}>
        {version} · macOS Sonoma or later · Free
      </p>
    </section>
  );
}

function QxSiteFooter({ githubUrl = 'https://github.com/c0/quixote' }) {
  return (
    <footer style={{
      textAlign: 'center', fontSize: '0.82rem', color: QX_SITE.fg3,
      fontFamily: QX_SITE.fontSans,
    }}>
      <p style={{ margin: 0 }}>
        © 2026 · <a href={githubUrl} style={{ color: QX_SITE.accent, textDecoration: 'none' }}>Open source</a> under MIT
      </p>
    </footer>
  );
}

Object.assign(window, { QxSiteHero, QxSiteFooter });
