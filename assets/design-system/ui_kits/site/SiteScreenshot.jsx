// Screenshot frame — a softly-bordered, shadowed macOS window holding a product shot.
// The reference png already contains window chrome, so we just present it.

function QxScreenshotFrame({ src, alt = '', caption }) {
  return (
    <figure style={{
      margin: 0,
      display: 'flex', flexDirection: 'column', gap: 14,
      fontFamily: QX_SITE.fontSans,
    }}>
      <div style={{
        position: 'relative',
        borderRadius: 12,
        border: `1px solid ${QX_SITE.border}`,
        background: 'rgba(10, 12, 16, 0.6)',
        boxShadow: '0 30px 90px rgba(0, 0, 0, 0.55), 0 4px 14px rgba(0, 0, 0, 0.35)',
        overflow: 'hidden',
      }}>
        <img src={src} alt={alt} style={{
          display: 'block',
          width: '100%', height: 'auto',
          // Subtle inner edge so the screenshot doesn't look pasted on
        }} />
        <div aria-hidden="true" style={{
          position: 'absolute', inset: 0, pointerEvents: 'none',
          boxShadow: 'inset 0 0 0 1px rgba(255, 255, 255, 0.04)',
          borderRadius: 12,
        }} />
      </div>
      {caption ? (
        <figcaption style={{
          fontFamily: QX_SITE.fontMono,
          fontSize: 11,
          letterSpacing: '0.18em',
          textTransform: 'uppercase',
          color: QX_SITE.fg3,
          textAlign: 'center',
        }}>
          {caption}
        </figcaption>
      ) : null}
    </figure>
  );
}

// Wider container that breaks out of the 720px text column for a screenshot.
function QxScreenshotBleed({ children, maxWidth = 1100 }) {
  return (
    <div style={{
      // Negative-margin trick to escape the 720px text column.
      width: `min(${maxWidth}px, calc(100vw - 32px))`,
      marginLeft: '50%',
      transform: 'translateX(-50%)',
      position: 'relative',
    }}>
      {children}
    </div>
  );
}

Object.assign(window, { QxScreenshotFrame, QxScreenshotBleed });
