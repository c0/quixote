// Shared primitives for the Quixote desktop UI kit.
// Designed to mirror QuixoteTheme.swift 1:1.

const { useState } = React;

// ---------- Icon (Lucide, drawn inline so we don't need a runtime lib) ----------
// Tiny subset — add as needed. Matches Lucide stroke-width: 2, rounded caps.
const QX_ICONS = {
  plus:        <><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></>,
  x:           <><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></>,
  'chevron-down': <polyline points="6 9 12 15 18 9"/>,
  'chevron-left':  <polyline points="15 18 9 12 15 6"/>,
  'chevron-right': <polyline points="9 18 15 12 9 6"/>,
  play:        <polygon points="6 3 20 12 6 21 6 3" fill="currentColor" stroke="none"/>,
  download:    <><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></>,
  'sliders-horizontal': <><line x1="21" y1="4" x2="14" y2="4"/><line x1="10" y1="4" x2="3" y2="4"/><line x1="21" y1="12" x2="12" y2="12"/><line x1="8" y1="12" x2="3" y2="12"/><line x1="21" y1="20" x2="16" y2="20"/><line x1="12" y1="20" x2="3" y2="20"/><line x1="14" y1="2" x2="14" y2="6"/><line x1="8" y1="10" x2="8" y2="14"/><line x1="16" y1="18" x2="16" y2="22"/></>,
  'trash-2':   <><polyline points="3 6 5 6 21 6"/><path d="M19 6l-2 14a2 2 0 0 1-2 2H9a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2"/></>,
  'table-2':   <><path d="M9 3H5a2 2 0 0 0-2 2v4m6-6h10a2 2 0 0 1 2 2v4M9 3v18m0 0H5a2 2 0 0 1-2-2V9m6 12h10a2 2 0 0 0 2-2V9M3 9h18"/></>,
  'info':      <><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></>,
  'dot':       <circle cx="12" cy="12" r="4" fill="currentColor" stroke="none"/>,
  'arrow-up-right': <><line x1="7" y1="17" x2="17" y2="7"/><polyline points="7 7 17 7 17 17"/></>,
  copy:        <><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></>,
};

function QxIcon({ name, size = 14, color, stroke = 2, style }) {
  const path = QX_ICONS[name];
  if (!path) return null;
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke={color || 'currentColor'}
      strokeWidth={stroke}
      strokeLinecap="round"
      strokeLinejoin="round"
      style={{ flex: 'none', display: 'block', ...style }}
    >
      {path}
    </svg>
  );
}

// ---------- Theme tokens, mirrored from QuixoteTheme.swift ----------
const QX = {
  appBg:       'rgb(23, 23, 26)',
  panel:       'rgb(33, 33, 36)',
  panelRaised: 'rgb(41, 41, 43)',
  card:        'rgb(28, 28, 31)',
  selection:   'rgb(56, 56, 61)',
  fg1:         'rgb(242, 242, 245)',
  fg2:         'rgb(143, 151, 173)',
  fg3:         'rgb(110, 115, 130)',
  divider:     'rgba(255, 255, 255, 0.08)',
  blue:        'rgb(48, 107, 240)',
  blueMuted:   'rgb(71, 140, 255)',
  green:       'rgb(56, 219, 122)',
  red:         'rgb(212, 41, 69)',
  orange:      'rgb(242, 158, 59)',
  fontSans:    '"Inter Tight", "SF Pro Display", system-ui, -apple-system, sans-serif',
  fontMono:    '"JetBrains Mono", ui-monospace, "SF Mono", Menlo, monospace',
};

// ---------- Section label: "MODEL" / "VARIABLES" / "SYSTEM MESSAGE" ----------
function QxSectionLabel({ children, style }) {
  return (
    <div style={{
      fontFamily: QX.fontSans,
      fontSize: 12,
      fontWeight: 600,
      letterSpacing: '0.2em',
      textTransform: 'uppercase',
      color: QX.fg2,
      ...style,
    }}>{children}</div>
  );
}

// ---------- Buttons ----------
function QxPrimaryButton({ icon, label, onClick, hasCaret, disabled, style }) {
  const [hover, setHover] = useState(false);
  const [press, setPress] = useState(false);
  return (
    <div style={{ display: 'inline-flex', borderRadius: 6, overflow: 'hidden', opacity: disabled ? 0.5 : 1, ...style }}>
      <button
        onClick={disabled ? undefined : onClick}
        onMouseEnter={() => setHover(true)} onMouseLeave={() => { setHover(false); setPress(false); }}
        onMouseDown={() => setPress(true)} onMouseUp={() => setPress(false)}
        style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          padding: '8px 14px',
          background: press ? 'rgba(48,107,240,0.85)' : QX.blue,
          color: '#fff',
          border: 'none',
          fontFamily: QX.fontSans,
          fontSize: 12, fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase',
          cursor: disabled ? 'default' : 'pointer',
        }}
      >
        {icon && <QxIcon name={icon} size={12} color="#fff" />}
        <span>{label}</span>
      </button>
      {hasCaret && (
        <div style={{
          width: 1, background: 'rgba(255,255,255,0.1)',
        }} />
      )}
      {hasCaret && (
        <button style={{
          width: 28, display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          background: press ? 'rgba(48,107,240,0.85)' : QX.blue, border: 'none', color: '#fff', cursor: 'pointer',
        }}>
          <QxIcon name="chevron-down" size={10} color="#fff" stroke={2.5} />
        </button>
      )}
    </div>
  );
}

function QxSecondaryButton({ icon, label, onClick, disabled, style }) {
  const [press, setPress] = useState(false);
  return (
    <button
      onClick={disabled ? undefined : onClick}
      onMouseDown={() => setPress(true)} onMouseUp={() => setPress(false)} onMouseLeave={() => setPress(false)}
      style={{
        display: 'inline-flex', alignItems: 'center', gap: 6,
        padding: '8px 12px',
        background: QX.panelRaised,
        color: QX.fg1,
        opacity: press ? 0.85 : (disabled ? 0.45 : 1),
        border: `1px solid ${QX.divider}`,
        borderRadius: 6,
        fontFamily: QX.fontSans,
        fontSize: 12, fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase',
        cursor: disabled ? 'default' : 'pointer',
        ...style,
      }}
    >
      {icon && <QxIcon name={icon} size={12} />}
      <span>{label}</span>
    </button>
  );
}

// ---------- Chip ----------
function QxChip({ text, closable = true, muted = false, mono = true }) {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '5px 9px',
      background: muted ? QX.panel : QX.selection,
      border: `1px solid ${QX.divider}`,
      borderRadius: 6,
      fontFamily: mono ? QX.fontMono : QX.fontSans,
      fontSize: 12, fontWeight: 500,
      color: muted ? QX.fg2 : QX.fg1,
      whiteSpace: 'nowrap',
    }}>
      <span>{text}</span>
      {closable && <QxIcon name="x" size={11} color={QX.fg2} />}
    </div>
  );
}

// ---------- Card ----------
function QxCard({ children, style }) {
  return (
    <div style={{
      background: QX.card,
      border: `1px solid ${QX.divider}`,
      borderRadius: 6,
      padding: 14,
      ...style,
    }}>{children}</div>
  );
}

// ---------- Divider ----------
function QxRowDivider() {
  return <div style={{ height: 1, background: QX.divider, width: '100%' }} />;
}
function QxVDivider() {
  return <div style={{ width: 1, background: QX.divider, alignSelf: 'stretch' }} />;
}

// Expose globals
Object.assign(window, {
  QX, QxIcon, QxSectionLabel, QxPrimaryButton, QxSecondaryButton, QxChip, QxCard, QxRowDivider, QxVDivider,
});
