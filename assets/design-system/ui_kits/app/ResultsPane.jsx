// Results table pane — dataset header + RUN/DOWNLOAD + sticky grid + optional stats footer.

function QxResultsPane({ dataset, subtitle, columns, rows, onRun, onDownload, stats, statsVariant = 'bar' }) {
  return (
    <section style={{
      flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column',
      background: QX.panel, color: QX.fg1, fontFamily: QX.fontSans,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 14px' }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 18, fontWeight: 700, color: QX.fg1, whiteSpace: 'nowrap' }}>{dataset}</div>
          <div style={{
            fontFamily: QX.fontMono, fontSize: 11, fontWeight: 500,
            letterSpacing: '0.18em', textTransform: 'uppercase', color: QX.fg2, marginTop: 2,
            whiteSpace: 'nowrap',
          }}>{subtitle}</div>
        </div>
        <QxSecondaryButton icon="download" label="Download" onClick={onDownload} />
        <QxPrimaryButton icon="play" label="Run" hasCaret onClick={onRun} />
      </div>
      <QxRowDivider />
      <div style={{ flex: 1, overflow: 'auto', minHeight: 0 }}>
        <QxDataTable columns={columns} rows={rows} />
      </div>
      {stats && window.QxStatsPanel && <QxStatsPanel stats={stats} variant={statsVariant} />}
    </section>
  );
}

function QxDataTable({ columns, rows }) {
  const colWidths = columns.map(c => c.width || 140);
  const totalW = 52 + colWidths.reduce((a, b) => a + b, 0);
  return (
    <div style={{ minWidth: totalW, fontFamily: QX.fontSans }}>
      {/* Header */}
      <div style={{
        display: 'flex', position: 'sticky', top: 0, zIndex: 1,
        background: QX.panelRaised, borderBottom: `1px solid ${QX.divider}`,
      }}>
        <div style={{ width: 52, padding: '10px', textAlign: 'right',
          fontFamily: QX.fontMono, fontSize: 11, fontWeight: 600,
          letterSpacing: '0.1em', textTransform: 'uppercase', color: QX.fg2,
          borderRight: `1px solid ${QX.divider}` }}>#</div>
        {columns.map((c, i) => (
          <div key={c.key} style={{
            width: colWidths[i], padding: '10px 12px',
            fontFamily: QX.fontMono, fontSize: 11, fontWeight: 600,
            letterSpacing: '0.1em', textTransform: 'uppercase', color: QX.fg2,
            borderRight: `1px solid ${QX.divider}`, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
          }}>{c.label || c.key}</div>
        ))}
      </div>
      {/* Rows */}
      {rows.map((r, ri) => (
        <div key={ri} style={{
          display: 'flex',
          background: ri % 2 === 0 ? 'transparent' : 'rgba(41,41,43,0.45)',
          borderBottom: `1px solid ${QX.divider}`,
        }}>
          <div style={{ width: 52, padding: '8px 10px', textAlign: 'right',
            fontFamily: QX.fontMono, fontSize: 11, color: QX.fg3,
            borderRight: `1px solid ${QX.divider}` }}>{ri + 1}</div>
          {columns.map((c, i) => {
            const v = r[c.key];
            const isBool = v === 'true' || v === 'false' || v === true || v === false;
            const isNum = !isBool && v != null && v !== '' && !isNaN(Number(v));
            return (
              <div key={c.key} style={{
                width: colWidths[i], padding: '8px 12px',
                fontFamily: (isBool || isNum) ? QX.fontMono : QX.fontSans,
                fontSize: 11,
                color: isBool ? QX.blueMuted : QX.fg1,
                borderRight: `1px solid ${QX.divider}`,
                whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
              }}>{v == null ? '' : String(v)}</div>
            );
          })}
        </div>
      ))}
    </div>
  );
}

Object.assign(window, { QxResultsPane, QxDataTable });
