// Feature grid — numbered groups with a hairline rule, items in a 2-column responsive grid.
// Each item: bold name on top, muted description below. Monospace numbering ties to the app's
// uppercase-tracked label vocabulary.

const QX_FEATURE_GROUPS = [
  {
    label: 'Models',
    items: [
      ['Multi-provider',     'OpenAI, Anthropic, Google, and local. One place for keys.'],
      ['Side-by-side',       'Run two models on the same data. Compare in adjacent columns.'],
      ['Cost meter',         'Tokens and dollars per run, per row, per model.'],
      ['Parallel rows',      'Configurable concurrency. Sensible defaults per provider.'],
    ],
  },
  {
    label: 'Data',
    items: [
      ['File support',       'Open CSV, TSV, JSON, or Excel. No import step, no conversion.'],
      ['Column variables',   'Reference any column with {{column_name}} inside a prompt.'],
      ['Live table',         'Output streams into a new column as each row finishes.'],
      ['Sample mode',        'Try a prompt on the first 5 rows before fanning out.'],
      ['Export',             'Download the enriched file in the same format you opened.'],
    ],
  },
  {
    label: 'Prompts',
    items: [
      ['Variants',           'Save multiple prompt drafts per file. Switch with a click.'],
      ['System message',     'Set tone, persona, response style.'],
      ['Parameters',         'Temperature, max tokens, top-p — visible at a glance.'],
      ['Substitution preview', 'See exactly what the model will receive for any row.'],
      ['Reusable templates', 'Save a prompt once, drop it on any compatible file.'],
    ],
  },
  {
    label: 'Run',
    items: [
      ['Streaming output',   'Tokens land in the cell as they arrive. No spinner-staring.'],
      ['Pause & resume',     'Stop mid-run. Pick up exactly where you left off.'],
      ['Retry failed',       'Re-run only the rows that errored. Keep the rest.'],
      ['Local-only',         'Files stay on your machine. Keys stored in the system keychain.'],
    ],
  },
  {
    label: 'Stats',
    items: [
      ['Cost estimate',      'Project the spend for the full file from a 5-row sample. See the bill before you commit.'],
      ['Running total',      'Live dollar count and tokens in/out, updated as rows complete.'],
      ['Latency p50 / p95',  'Tail latency tracked per model with a sparkline of the last few minutes.'],
      ['Throughput',         'Rows per second, with ETA to completion at the current rate.'],
      ['Per-model breakdown','Rows, latency, similarity, and cost split by model in one table.'],
      ['Similarity score',   'Optional cosine similarity vs a reference column. Quick read on quality drift.'],
      ['Error tally',        'Failed rows grouped by reason and count. One click to retry just those.'],
      ['Token usage',        'Input vs output tokens per run. Compare prompt variants by efficiency.'],
    ],
  },
];

function QxFeatureItem({ name, desc }) {
  return (
    <div style={{
      display: 'flex', flexDirection: 'column', gap: 6,
      paddingTop: 14,
      borderTop: `1px solid ${QX_SITE.border}`,
    }}>
      <div style={{
        fontFamily: QX_SITE.fontSans,
        fontSize: '0.98rem',
        fontWeight: 600,
        color: QX_SITE.fg1,
        letterSpacing: '-0.005em',
      }}>
        {name}
      </div>
      <div style={{
        fontFamily: QX_SITE.fontSans,
        fontSize: '0.92rem',
        lineHeight: 1.5,
        color: QX_SITE.fg2,
        textWrap: 'pretty',
      }}>
        {desc}
      </div>
    </div>
  );
}

function QxFeatureSection({ index, label, items }) {
  const num = String(index + 1).padStart(2, '0');
  return (
    <section style={{ display: 'flex', flexDirection: 'column', gap: 22 }}>
      <header style={{
        display: 'flex', alignItems: 'baseline', gap: 18,
        paddingBottom: 14,
        borderBottom: `1px solid ${QX_SITE.border}`,
      }}>
        <span style={{
          fontFamily: QX_SITE.fontMono,
          fontSize: 11,
          fontWeight: 500,
          letterSpacing: '0.18em',
          color: QX_SITE.fg3,
        }}>
          {num}
        </span>
        <h2 style={{
          fontFamily: QX_SITE.fontSans,
          fontSize: 'clamp(1.6rem, 3.2vw, 2.1rem)',
          fontWeight: 600,
          letterSpacing: '-0.025em',
          color: QX_SITE.fg1,
          margin: 0,
          flex: 1,
          lineHeight: 1,
        }}>
          {label}
        </h2>
        <span style={{
          fontFamily: QX_SITE.fontMono,
          fontSize: 11,
          letterSpacing: '0.18em',
          textTransform: 'uppercase',
          color: QX_SITE.fg3,
        }}>
          {items.length} items
        </span>
      </header>
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))',
        gap: '20px 32px',
      }}>
        {items.map(([name, desc]) => (
          <QxFeatureItem key={name} name={name} desc={desc} />
        ))}
      </div>
    </section>
  );
}

function QxSiteFeatures({ groups = QX_FEATURE_GROUPS }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 72 }}>
      {groups.map((g, i) => (
        <QxFeatureSection key={g.label} index={i} label={g.label} items={g.items} />
      ))}
    </div>
  );
}

Object.assign(window, { QxSiteFeatures, QxFeatureSection, QxFeatureItem, QX_FEATURE_GROUPS });
