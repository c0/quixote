// Right sheet — opens when the arrow icon on an output cell is clicked.
// Dense, mono-numeric, single blue accent. Mirrors the rest of the app chrome.

function QxOutputDetail({ detail, onClose }) {
  const [tab, setTab] = React.useState('content');
  const [copied, setCopied] = React.useState(false);
  if (!detail) return null;

  const copyText = () => {
    const text = tab === 'raw' ? JSON.stringify({ output: detail.output || '' }, null, 2) : (detail.output || '');
    if (navigator.clipboard) navigator.clipboard.writeText(text).catch(() => {});
    setCopied(true);
    setTimeout(() => setCopied(false), 1200);
  };

  const {
    rowIndex, promptName, model, status = 'Completed',
    tokens = 169, tokensIn = 155, tokensOut = 14,
    cost = '$0.0002', latencyMs = 681,
    sim = 0.108, r1 = 0.074, r2 = 0.038, rl = 0.074,
    output = '',
  } = detail;

  return (
    <aside style={{
      width: 380, flex: 'none', minWidth: 0,
      display: 'flex', flexDirection: 'column',
      background: QX.panel, color: QX.fg1,
      fontFamily: QX.fontSans,
      borderLeft: `1px solid ${QX.divider}`,
    }}>
      {/* ---------- Header ---------- */}
      <div style={{ padding: '12px 16px 14px' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 8 }}>
          <div style={{ minWidth: 0 }}>
            <QxSectionLabel>Output Detail</QxSectionLabel>
            <div style={{
              marginTop: 8, fontSize: 15, fontWeight: 700, color: QX.fg1,
              whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
            }}>
              Row {rowIndex}
              <span style={{ color: QX.fg3, fontWeight: 500, margin: '0 6px' }}>·</span>
              {promptName}
            </div>
          </div>
          <QxIconButton name="x" onClick={onClose} ariaLabel="Close output detail" />
        </div>
      </div>
      <QxRowDivider />

      {/* ---------- Body ---------- */}
      <div style={{ flex: 1, minHeight: 0, overflow: 'auto', padding: '14px 16px 16px',
        display: 'flex', flexDirection: 'column', gap: 14 }}>

        {/* Model name */}
        <div style={{
          fontFamily: QX.fontMono, fontSize: 12, color: QX.fg2,
          letterSpacing: '0.04em',
        }}>{model}</div>

        {/* Metrics grid */}
        <QxMetricGrid items={[
          { label: 'Status',  value: status, accent: status === 'Completed' ? QX.green : null },
          { label: 'Tokens',  value: tokens },
          { label: 'In',      value: tokensIn },
          { label: 'Out',     value: tokensOut },
          { label: 'Cost',    value: cost },
          { label: 'Latency', value: latencyMs, unit: 'ms' },
          { label: 'Sim',     value: sim.toFixed(3) },
          { label: 'R1',      value: r1.toFixed(3) },
          { label: 'R2',      value: r2.toFixed(3) },
          { label: 'RL',      value: rl.toFixed(3) },
        ]} />

        {/* Tabs */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 10,
          paddingTop: 6, borderTop: `1px solid ${QX.divider}`,
        }}>
          <span style={{
            fontFamily: QX.fontSans, fontSize: 11, fontWeight: 600,
            letterSpacing: '0.18em', textTransform: 'uppercase', color: QX.fg3,
          }}>View</span>
          <QxSegmented
            options={[['content', 'Content'], ['raw', 'Raw']]}
            value={tab} onChange={setTab}
          />
        </div>

        {/* Output content */}
        <div>
          <QxSectionLabel style={{ marginBottom: 8 }}>{tabLabel(tab)}</QxSectionLabel>
          <div style={{
            position: 'relative',
            background: QX.card, border: `1px solid ${QX.divider}`, borderRadius: 6,
            padding: 12, paddingRight: 36, minHeight: 140,
            fontFamily: QX.fontMono, fontSize: 12, color: QX.fg1, lineHeight: 1.55,
            whiteSpace: 'pre-wrap', wordBreak: 'break-word',
          }}>
            <div style={{ position: 'absolute', top: 6, right: 6 }}>
              <QxIconButton
                name={copied ? 'dot' : 'copy'}
                onClick={copyText}
                ariaLabel={copied ? 'Copied' : 'Copy to clipboard'}
              />
            </div>
            {tab === 'raw'
              ? <span style={{ color: QX.fg2 }}>{JSON.stringify({ output }, null, 2)}</span>
              : output || <span style={{ color: QX.fg3 }}>—</span>}
          </div>
        </div>
      </div>
    </aside>
  );
}

function tabLabel(t) {
  return t === 'content' ? 'Content' : t === 'raw' ? 'Raw' : 'Output';
}

// ---------- Small parts ----------

function QxMetricGrid({ items }) {
  return (
    <div style={{
      display: 'grid', gridTemplateColumns: '1fr 1fr',
      rowGap: 10, columnGap: 18,
    }}>
      {items.map((m, i) => (
        <div key={i} style={{ display: 'flex', alignItems: 'baseline', gap: 8, minWidth: 0 }}>
          <span style={{
            fontFamily: QX.fontMono, fontSize: 10, fontWeight: 600,
            letterSpacing: '0.16em', textTransform: 'uppercase', color: QX.fg3,
            flex: 'none',
          }}>{m.label}</span>
          <span style={{
            fontFamily: QX.fontMono, fontSize: 12, fontWeight: 600,
            color: m.accent || QX.fg1,
            fontVariantNumeric: 'tabular-nums',
            whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
          }}>
            {m.value}
            {m.unit && <span style={{
              color: QX.fg3, fontSize: 10, marginLeft: 3,
              letterSpacing: '0.12em', textTransform: 'uppercase',
            }}>{m.unit}</span>}
          </span>
        </div>
      ))}
    </div>
  );
}

function QxIconButton({ name, onClick, ariaLabel }) {
  const [hover, setHover] = React.useState(false);
  return (
    <button
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      aria-label={ariaLabel}
      style={{
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        width: 24, height: 24, padding: 0,
        background: hover ? QX.selection : 'transparent',
        border: `1px solid ${hover ? QX.divider : 'transparent'}`,
        borderRadius: 4, cursor: 'pointer',
        color: hover ? QX.fg1 : QX.fg2,
        flex: 'none',
      }}
    >
      <QxIcon name={name} size={12} stroke={2} />
    </button>
  );
}

Object.assign(window, { QxOutputDetail, QxIconButton, QxMetricGrid });
