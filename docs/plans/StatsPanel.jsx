// StatsPanel — analytics summary for the results pane footer.
//
// Two variants (toggle via prop):
//   - "bar"  : single-row status strip, 36px tall. Always-visible while running.
//   - "grid" : expanded multi-metric grid with per-model breakdown. Click-to-expand from the bar.
//
// Voice: dense, monospace-heavy, one-accent. SIM/latency/tokens are first-class numbers.
// Uses QX tokens from Primitives.jsx.

function QxMiniBar({ value, total, variant = 'blue' }) {
  const pct = total > 0 ? Math.max(0, Math.min(1, value / total)) : 0;
  const fill = variant === 'red' ? QX.red : variant === 'green' ? QX.green : QX.blue;
  return (
    <div style={{
      position: 'relative', width: 120, height: 4, borderRadius: 2,
      background: 'rgba(255,255,255,0.06)', overflow: 'hidden',
    }}>
      <div style={{
        position: 'absolute', left: 0, top: 0, bottom: 0,
        width: `${pct * 100}%`, background: fill,
        transition: 'width 240ms ease-out',
      }} />
    </div>
  );
}

function QxMetric({ label, value, unit, tone = 'fg1', trend, mono = true, title }) {
  const color = tone === 'blue' ? QX.blueMuted : tone === 'red' ? QX.red
              : tone === 'green' ? QX.green : tone === 'fg2' ? QX.fg2 : QX.fg1;
  return (
    <div title={title} style={{
      display: 'flex', flexDirection: 'column', gap: 2, minWidth: 0,
      padding: '0 14px', borderLeft: `1px solid ${QX.divider}`,
    }}>
      <div style={{
        fontFamily: QX.fontMono, fontSize: 10, fontWeight: 600,
        letterSpacing: '0.16em', textTransform: 'uppercase', color: QX.fg3,
        whiteSpace: 'nowrap',
      }}>{label}</div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
        <span style={{
          fontFamily: mono ? QX.fontMono : QX.fontSans,
          fontSize: 14, fontWeight: 600, color,
          letterSpacing: '-0.01em', fontVariantNumeric: 'tabular-nums',
        }}>{value}</span>
        {unit && <span style={{
          fontFamily: QX.fontMono, fontSize: 10, color: QX.fg3,
          textTransform: 'uppercase', letterSpacing: '0.14em',
        }}>{unit}</span>}
        {trend != null && (
          <span style={{
            fontFamily: QX.fontMono, fontSize: 10,
            color: trend >= 0 ? QX.green : QX.red,
            fontVariantNumeric: 'tabular-nums',
          }}>{trend >= 0 ? '▲' : '▼'}{Math.abs(trend).toFixed(1)}%</span>
        )}
      </div>
    </div>
  );
}

// Tiny sparkline — 40×16 polyline. Expects array of numbers; normalized auto.
function QxSparkline({ data, color = QX.blueMuted, w = 56, h = 16 }) {
  if (!data || data.length < 2) return null;
  const min = Math.min(...data), max = Math.max(...data);
  const range = max - min || 1;
  const step = w / (data.length - 1);
  const pts = data.map((v, i) =>
    `${(i * step).toFixed(1)},${(h - ((v - min) / range) * h).toFixed(1)}`
  ).join(' ');
  return (
    <svg width={w} height={h} style={{ display: 'block', flex: 'none' }}>
      <polyline points={pts} fill="none" stroke={color} strokeWidth="1.25"
        strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

// Pulsing dot for the RUNNING state.
function QxRunningDot() {
  return (
    <span style={{ position: 'relative', width: 8, height: 8, display: 'inline-block' }}>
      <span style={{
        position: 'absolute', inset: 0, borderRadius: 999, background: QX.green,
      }} />
      <span style={{
        position: 'absolute', inset: -3, borderRadius: 999,
        border: `1px solid ${QX.green}`, opacity: 0.35,
        animation: 'qxPulse 1.4s ease-out infinite',
      }} />
      <style>{`@keyframes qxPulse {
        0%   { transform: scale(0.8); opacity: 0.45; }
        80%  { transform: scale(2.1); opacity: 0; }
        100% { transform: scale(2.1); opacity: 0; }
      }`}</style>
    </span>
  );
}

// -----------------------------------------------------------------------------
// Variant A — status bar (single row)
// -----------------------------------------------------------------------------
function QxStatsBar({ stats, expanded, onToggle }) {
  const {
    status = 'running',          // 'running' | 'idle' | 'paused' | 'done' | 'failed'
    processed = 0, total = 0,
    tps = 0,                      // rows/sec
    latencyP50 = 0, latencyP95 = 0, // ms
    tokensIn = 0, tokensOut = 0,
    cost = 0,
    sim = null,                   // 0..1 or null if not configured
    failed = 0,
    eta = null,                   // seconds remaining
    latencyTrail = [],
  } = stats;

  const pct = total ? (processed / total) : 0;
  const statusLabel = {
    running: 'RUNNING', idle: 'IDLE', paused: 'PAUSED', done: 'COMPLETE', failed: 'FAILED',
  }[status] || status.toUpperCase();
  const statusDot = {
    running: <QxRunningDot />,
    idle:    <span style={{ width: 8, height: 8, borderRadius: 999, background: QX.fg3, display: 'inline-block' }} />,
    paused:  <span style={{ width: 8, height: 8, borderRadius: 999, background: QX.orange, display: 'inline-block' }} />,
    done:    <span style={{ width: 8, height: 8, borderRadius: 999, background: QX.green, display: 'inline-block' }} />,
    failed:  <span style={{ width: 8, height: 8, borderRadius: 999, background: QX.red, display: 'inline-block' }} />,
  }[status];

  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 0,
      padding: '0 14px', height: 44,
      background: QX.panelRaised, borderTop: `1px solid ${QX.divider}`,
      color: QX.fg1, fontFamily: QX.fontSans, flex: 'none',
    }}>
      {/* Status */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, paddingRight: 14 }}>
        {statusDot}
        <span style={{
          fontFamily: QX.fontMono, fontSize: 11, fontWeight: 700,
          letterSpacing: '0.18em', color: status === 'failed' ? QX.red : status === 'paused' ? QX.orange : QX.fg1,
        }}>{statusLabel}</span>
      </div>

      {/* Progress — rows processed + bar */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 10,
        padding: '0 14px', borderLeft: `1px solid ${QX.divider}`,
      }}>
        <span style={{
          fontFamily: QX.fontMono, fontSize: 13, fontWeight: 600, color: QX.fg1,
          fontVariantNumeric: 'tabular-nums',
        }}>
          {processed.toLocaleString()}<span style={{ color: QX.fg3 }}> / {total.toLocaleString()}</span>
        </span>
        <QxMiniBar value={processed} total={total} variant={failed > 0 ? 'red' : 'blue'} />
        <span style={{ fontFamily: QX.fontMono, fontSize: 11, color: QX.fg2, fontVariantNumeric: 'tabular-nums' }}>
          {(pct * 100).toFixed(1)}%
        </span>
      </div>

      {/* Throughput */}
      <QxMetric label="Throughput" value={tps.toFixed(1)} unit="rows/s" />

      {/* Latency with sparkline */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        padding: '0 14px', borderLeft: `1px solid ${QX.divider}`,
      }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          <div style={{
            fontFamily: QX.fontMono, fontSize: 10, fontWeight: 600,
            letterSpacing: '0.16em', textTransform: 'uppercase', color: QX.fg3,
          }}>Latency p50 / p95</div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
            <span style={{
              fontFamily: QX.fontMono, fontSize: 14, fontWeight: 600, color: QX.fg1,
              fontVariantNumeric: 'tabular-nums',
            }}>{latencyP50}</span>
            <span style={{ fontFamily: QX.fontMono, fontSize: 10, color: QX.fg3 }}>/</span>
            <span style={{
              fontFamily: QX.fontMono, fontSize: 14, fontWeight: 600, color: QX.fg1,
              fontVariantNumeric: 'tabular-nums',
            }}>{latencyP95}</span>
            <span style={{ fontFamily: QX.fontMono, fontSize: 10, color: QX.fg3, letterSpacing: '0.14em', textTransform: 'uppercase' }}>ms</span>
          </div>
        </div>
        <QxSparkline data={latencyTrail} />
      </div>

      {/* Tokens */}
      <QxMetric
        label="Tokens in/out"
        value={`${fmtK(tokensIn)} / ${fmtK(tokensOut)}`}
        title={`${tokensIn.toLocaleString()} input · ${tokensOut.toLocaleString()} output`}
      />

      {/* Cost */}
      <QxMetric label="Cost" value={`$${cost.toFixed(2)}`} />

      {/* SIM (optional) */}
      {sim != null && (
        <QxMetric
          label="Similarity (mean)"
          value={sim.toFixed(3)}
          tone={sim >= 0.8 ? 'fg1' : sim >= 0.6 ? 'fg1' : 'red'}
          title="Mean cosine similarity vs reference column"
        />
      )}

      {/* Failed (if any) */}
      {failed > 0 && (
        <QxMetric label="Failed" value={failed.toLocaleString()} tone="red" />
      )}

      <div style={{ flex: 1 }} />

      {/* ETA + expand toggle */}
      {eta != null && status === 'running' && (
        <span style={{
          fontFamily: QX.fontMono, fontSize: 11, color: QX.fg2,
          textTransform: 'uppercase', letterSpacing: '0.16em', marginRight: 12,
          fontVariantNumeric: 'tabular-nums',
        }}>ETA {fmtEta(eta)}</span>
      )}
      <button onClick={onToggle} aria-label={expanded ? 'Collapse details' : 'Expand details'} style={{
        background: 'transparent', border: `1px solid ${QX.divider}`, color: QX.fg2,
        borderRadius: 4, padding: '4px 8px', cursor: 'pointer',
        fontFamily: QX.fontMono, fontSize: 10, fontWeight: 600,
        letterSpacing: '0.16em', textTransform: 'uppercase',
        display: 'flex', alignItems: 'center', gap: 6,
      }}>
        {expanded ? 'Less' : 'Details'}
        <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"
          style={{ transform: expanded ? 'rotate(180deg)' : 'none', transition: 'transform 160ms' }}>
          <polyline points="6 9 12 15 18 9"/>
        </svg>
      </button>
    </div>
  );
}

// -----------------------------------------------------------------------------
// Variant B — expanded grid (shown below the bar when `expanded`)
// -----------------------------------------------------------------------------
function QxStatsGrid({ stats }) {
  const { perModel = [], errors = [], tokensIn = 0, tokensOut = 0, cost = 0 } = stats;
  return (
    <div style={{
      background: QX.panel, borderTop: `1px solid ${QX.divider}`,
      padding: '14px 14px 16px', color: QX.fg1, fontFamily: QX.fontSans,
      display: 'grid', gridTemplateColumns: 'minmax(340px, 2fr) minmax(240px, 1fr) minmax(220px, 1fr)', gap: 18,
      flex: 'none',
    }}>
      {/* Per-model breakdown */}
      <section>
        <QxSubHeader label="Per model" meta={`${perModel.length} active`} />
        <div style={{
          border: `1px solid ${QX.divider}`, borderRadius: 6, overflow: 'hidden',
          background: QX.card,
        }}>
          <div style={{
            display: 'grid',
            gridTemplateColumns: '1.4fr 0.8fr 0.8fr 0.8fr 0.7fr 0.7fr',
            padding: '8px 12px', gap: 10,
            background: QX.panelRaised, borderBottom: `1px solid ${QX.divider}`,
            fontFamily: QX.fontMono, fontSize: 10, fontWeight: 600,
            letterSpacing: '0.14em', textTransform: 'uppercase', color: QX.fg2,
          }}>
            <span>Model</span>
            <span style={{ textAlign: 'right' }}>Rows</span>
            <span style={{ textAlign: 'right' }}>p50</span>
            <span style={{ textAlign: 'right' }}>p95</span>
            <span style={{ textAlign: 'right' }}>SIM</span>
            <span style={{ textAlign: 'right' }}>$</span>
          </div>
          {perModel.map((m, i) => (
            <div key={m.name} style={{
              display: 'grid',
              gridTemplateColumns: '1.4fr 0.8fr 0.8fr 0.8fr 0.7fr 0.7fr',
              padding: '8px 12px', gap: 10, alignItems: 'center',
              borderBottom: i < perModel.length - 1 ? `1px solid ${QX.divider}` : 'none',
              fontFamily: QX.fontMono, fontSize: 11, fontVariantNumeric: 'tabular-nums',
              background: i % 2 === 1 ? 'rgba(41,41,43,0.45)' : 'transparent',
            }}>
              <span style={{ display: 'flex', alignItems: 'center', gap: 8, color: QX.fg1 }}>
                <span style={{
                  width: 6, height: 6, borderRadius: 999,
                  background: m.status === 'running' ? QX.green : m.status === 'failed' ? QX.red : QX.fg3,
                }} />
                {m.name}
              </span>
              <span style={{ textAlign: 'right', color: QX.fg1 }}>{m.rows.toLocaleString()}</span>
              <span style={{ textAlign: 'right', color: QX.fg1 }}>{m.p50}</span>
              <span style={{ textAlign: 'right', color: QX.fg1 }}>{m.p95}</span>
              <span style={{ textAlign: 'right', color: m.sim >= 0.75 ? QX.fg1 : m.sim >= 0.5 ? QX.fg2 : QX.red }}>
                {m.sim.toFixed(3)}
              </span>
              <span style={{ textAlign: 'right', color: QX.fg1 }}>${m.cost.toFixed(2)}</span>
            </div>
          ))}
        </div>
      </section>

      {/* Tokens + cost */}
      <section>
        <QxSubHeader label="Usage" meta="total" />
        <div style={{
          border: `1px solid ${QX.divider}`, borderRadius: 6,
          background: QX.card, padding: '12px 14px',
          display: 'flex', flexDirection: 'column', gap: 12,
        }}>
          <QxBigStat label="Input tokens"  value={tokensIn.toLocaleString()} bar={tokensIn} of={tokensIn + tokensOut} color={QX.blueMuted} />
          <QxBigStat label="Output tokens" value={tokensOut.toLocaleString()} bar={tokensOut} of={tokensIn + tokensOut} color={QX.green} />
          <div style={{
            display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
            paddingTop: 10, borderTop: `1px solid ${QX.divider}`,
          }}>
            <span style={{
              fontFamily: QX.fontMono, fontSize: 10, fontWeight: 600,
              letterSpacing: '0.16em', textTransform: 'uppercase', color: QX.fg3,
            }}>Running total</span>
            <span style={{
              fontFamily: QX.fontMono, fontSize: 16, fontWeight: 600, color: QX.fg1,
              fontVariantNumeric: 'tabular-nums',
            }}>${cost.toFixed(2)}</span>
          </div>
        </div>
      </section>

      {/* Errors */}
      <section>
        <QxSubHeader label="Errors" meta={errors.length > 0 ? `${errors.reduce((s, e) => s + e.count, 0)} total` : 'none'} />
        <div style={{
          border: `1px solid ${QX.divider}`, borderRadius: 6,
          background: QX.card, padding: errors.length ? 0 : '18px',
          minHeight: 120,
        }}>
          {errors.length === 0 ? (
            <div style={{
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              height: '100%', minHeight: 80,
              fontFamily: QX.fontMono, fontSize: 11, color: QX.fg3,
              textTransform: 'uppercase', letterSpacing: '0.16em',
            }}>
              No errors
            </div>
          ) : errors.map((e, i) => (
            <div key={i} style={{
              padding: '10px 12px', borderBottom: i < errors.length - 1 ? `1px solid ${QX.divider}` : 'none',
              display: 'flex', alignItems: 'center', gap: 10,
              fontFamily: QX.fontMono, fontSize: 11, color: QX.fg1,
            }}>
              <span style={{ color: QX.red, fontSize: 13, lineHeight: 1 }}>●</span>
              <span style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {e.label}
              </span>
              <span style={{ color: QX.fg2, fontVariantNumeric: 'tabular-nums' }}>×{e.count}</span>
            </div>
          ))}
          {errors.length > 0 && (
            <div style={{
              padding: '10px 12px', borderTop: `1px solid ${QX.divider}`,
              display: 'flex', justifyContent: 'flex-end',
            }}>
              <button style={{
                background: 'transparent', border: `1px solid ${QX.divider}`, color: QX.fg1,
                borderRadius: 4, padding: '5px 10px', cursor: 'pointer',
                fontFamily: QX.fontSans, fontSize: 11, fontWeight: 700,
                letterSpacing: '0.08em', textTransform: 'uppercase',
              }}>Retry failed</button>
            </div>
          )}
        </div>
      </section>
    </div>
  );
}

// ---------- small helpers ----------

function QxSubHeader({ label, meta }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
      marginBottom: 8,
    }}>
      <span className="qx-section-label" style={{
        fontFamily: QX.fontSans, fontSize: 11, fontWeight: 600,
        letterSpacing: '0.2em', textTransform: 'uppercase', color: QX.fg2,
      }}>{label}</span>
      <span style={{
        fontFamily: QX.fontMono, fontSize: 10, fontWeight: 500,
        letterSpacing: '0.16em', textTransform: 'uppercase', color: QX.fg3,
      }}>{meta}</span>
    </div>
  );
}

function QxBigStat({ label, value, bar, of, color }) {
  const pct = of > 0 ? bar / of : 0;
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 6 }}>
        <span style={{
          fontFamily: QX.fontMono, fontSize: 10, fontWeight: 600,
          letterSpacing: '0.16em', textTransform: 'uppercase', color: QX.fg3,
        }}>{label}</span>
        <span style={{
          fontFamily: QX.fontMono, fontSize: 13, fontWeight: 600, color: QX.fg1,
          fontVariantNumeric: 'tabular-nums',
        }}>{value}</span>
      </div>
      <div style={{ height: 3, borderRadius: 2, background: 'rgba(255,255,255,0.06)', overflow: 'hidden' }}>
        <div style={{ width: `${pct * 100}%`, height: '100%', background: color, transition: 'width 300ms ease-out' }} />
      </div>
    </div>
  );
}

function fmtK(n) {
  if (n < 1000) return n.toString();
  if (n < 1_000_000) return (n / 1000).toFixed(1).replace(/\.0$/, '') + 'K';
  return (n / 1_000_000).toFixed(2).replace(/\.00$/, '') + 'M';
}

function fmtEta(s) {
  if (s < 60) return Math.round(s) + 's';
  const m = Math.floor(s / 60), sec = Math.round(s % 60);
  if (m < 60) return `${m}m ${sec.toString().padStart(2, '0')}s`;
  const h = Math.floor(m / 60);
  return `${h}h ${(m % 60).toString().padStart(2, '0')}m`;
}

// Default combined export — bar that toggles the grid.
function QxStatsPanel({ stats, defaultExpanded = false, variant = 'bar' }) {
  const [expanded, setExpanded] = React.useState(defaultExpanded);
  if (variant === 'grid') {
    // Always-expanded variant: show both.
    return (
      <div style={{ flex: 'none', display: 'flex', flexDirection: 'column' }}>
        <QxStatsBar stats={stats} expanded={true} onToggle={() => {}} />
        <QxStatsGrid stats={stats} />
      </div>
    );
  }
  return (
    <div style={{ flex: 'none', display: 'flex', flexDirection: 'column' }}>
      <QxStatsBar stats={stats} expanded={expanded} onToggle={() => setExpanded(v => !v)} />
      {expanded && <QxStatsGrid stats={stats} />}
    </div>
  );
}

Object.assign(window, {
  QxStatsPanel, QxStatsBar, QxStatsGrid,
  QxMiniBar, QxMetric, QxSparkline, QxRunningDot,
});
