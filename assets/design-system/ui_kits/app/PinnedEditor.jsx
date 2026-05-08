// Pinned prompt editor — model-agnostic. SYSTEM + PROMPT only.
// Detects {{tokens}} from the prompt and lists them, and offers "Run on…" to a dataset.

const { useState: useStatePin, useRef: useRefPin } = React;

function detectVars(text = '') {
  const seen = new Set();
  const re = /\{\{\s*([a-z0-9_]+)\s*\}\}/gi;
  let m;
  while ((m = re.exec(text)) !== null) seen.add(m[1]);
  return Array.from(seen);
}

function QxPinnedEditor({
  prompt, // { id, name, system, prompt, builtIn }
  onChange, // (patch) => void
  onDelete,
  onDuplicate,
  datasets, // [{ id, name }]
  onRunOn,  // (datasetId) => void
}) {
  const vars = detectVars(prompt.prompt + ' ' + (prompt.system || ''));
  const [pickerOpen, setPickerOpen] = useStatePin(false);
  const pickerRef = useRefPin(null);

  return (
    <section style={{
      width: 440, flex: 'none',
      display: 'flex', flexDirection: 'column',
      background: QX.panelRaised,
      borderRight: `1px solid ${QX.divider}`,
      color: QX.fg1, fontFamily: QX.fontSans,
    }}>
      {/* Header — pin glyph + editable name + actions */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 18px', minHeight: 44 }}>
        <QxIcon name="pin-fill" size={13} color={QX.blueMuted} />
        <input
          value={prompt.name}
          onChange={(e) => onChange?.({ name: e.target.value })}
          spellCheck={false}
          style={{
            flex: 1, minWidth: 0,
            background: 'transparent', border: 'none', outline: 'none',
            color: QX.fg1, fontFamily: QX.fontSans, fontSize: 14, fontWeight: 700,
            padding: 0,
          }}
        />
        <div style={{ position: 'relative' }} ref={pickerRef}>
          <QxSecondaryButton icon="play" label="Run on…" onClick={() => setPickerOpen(o => !o)} />
          {pickerOpen && (
            <QxRunOnPopover
              datasets={datasets}
              vars={vars}
              onPick={(id) => { setPickerOpen(false); onRunOn?.(id); }}
              onClose={() => setPickerOpen(false)}
            />
          )}
        </div>
        <button onClick={onDuplicate} title="Duplicate" style={iconBtnStyle()}>
          <QxIcon name="copy" size={13} color={QX.fg2} />
        </button>
        <button onClick={onDelete} title="Delete" style={iconBtnStyle()}>
          <QxIcon name="trash-2" size={13} color={QX.fg2} />
        </button>
      </div>
      <QxRowDivider />

      <div style={{ flex: 1, overflow: 'auto', padding: '14px 18px' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>

          {/* SYSTEM MESSAGE */}
          <div>
            <QxSectionLabel style={{ marginBottom: 10 }}>System Message</QxSectionLabel>
            <QxEditableArea
              value={prompt.system || ''}
              onChange={(v) => onChange?.({ system: v })}
              placeholder="Describe desired model behavior (tone, tool usage, response style)"
              minHeight={120}
            />
          </div>

          {/* PROMPT */}
          <div>
            <QxSectionLabel style={{ marginBottom: 10 }}>Prompt</QxSectionLabel>
            <QxEditableArea
              value={prompt.prompt || ''}
              onChange={(v) => onChange?.({ prompt: v })}
              placeholder={'Summarized in 3 bullet points:\n{{body_html}}'}
              minHeight={180}
            />
          </div>

          {/* REQUIRED VARIABLES */}
          <div>
            <QxSectionLabel style={{ marginBottom: 10 }}>Required Variables</QxSectionLabel>
            {vars.length === 0 ? (
              <div style={{ fontFamily: QX.fontMono, fontSize: 11, color: QX.fg3 }}>
                None — prompt is plain text. Add <span style={{ color: QX.fg2 }}>{'{{column_name}}'}</span> tokens to interpolate row values.
              </div>
            ) : (
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {vars.map(v => <QxChip key={v} text={v} closable={false} />)}
              </div>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}

function iconBtnStyle() {
  return {
    width: 26, height: 26, display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
    background: 'transparent', border: 'none', borderRadius: 4, cursor: 'pointer',
  };
}

function QxEditableArea({ value, onChange, placeholder, minHeight = 120 }) {
  return (
    <textarea
      value={value}
      onChange={(e) => onChange?.(e.target.value)}
      placeholder={placeholder}
      spellCheck={false}
      style={{
        display: 'block', width: '100%', resize: 'vertical', minHeight,
        background: QX.card, border: `1px solid ${QX.divider}`, borderRadius: 6,
        padding: 12,
        fontFamily: QX.fontMono, fontSize: 14, color: QX.fg1,
        lineHeight: 1.5, outline: 'none',
        boxSizing: 'border-box',
      }}
    />
  );
}

function QxRunOnPopover({ datasets, vars, onPick, onClose }) {
  return (
    <>
      <div onClick={onClose} style={{
        position: 'fixed', inset: 0, zIndex: 40,
      }} />
      <div style={{
        position: 'absolute', top: 'calc(100% + 6px)', right: 0, zIndex: 41,
        width: 260,
        background: QX.panelRaised,
        border: `1px solid ${QX.divider}`, borderRadius: 8,
        boxShadow: '0 24px 80px rgba(0,0,0,0.5)',
        padding: 6,
      }}>
        <div style={{
          padding: '8px 10px 6px',
          fontFamily: QX.fontSans, fontSize: 10, fontWeight: 700,
          letterSpacing: '0.22em', textTransform: 'uppercase', color: QX.fg3,
        }}>Apply To Dataset</div>
        {datasets.length === 0 && (
          <div style={{ padding: '6px 10px 10px', fontSize: 11, color: QX.fg3 }}>
            No datasets open. Open a file from the sidebar first.
          </div>
        )}
        {datasets.map(d => (
          <button key={d.id} onClick={() => onPick(d.id)} style={{
            display: 'flex', alignItems: 'center', gap: 10, width: '100%',
            padding: '8px 10px', background: 'transparent', border: 'none',
            borderRadius: 6, color: QX.fg1, cursor: 'pointer', textAlign: 'left',
            fontFamily: QX.fontSans, fontSize: 12, fontWeight: 600,
          }}
            onMouseEnter={(e) => e.currentTarget.style.background = QX.selection}
            onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}
          >
            <QxIcon name="table-2" size={13} color={QX.fg2} />
            <div style={{ flex: 1, minWidth: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
              {d.name}
            </div>
            <QxIcon name="arrow-up-right" size={12} color={QX.fg3} />
          </button>
        ))}
        {vars.length > 0 && datasets.length > 0 && (
          <div style={{
            padding: '8px 10px 6px', borderTop: `1px solid ${QX.divider}`, marginTop: 4,
            fontFamily: QX.fontMono, fontSize: 10, color: QX.fg3, lineHeight: 1.5,
          }}>
            Will check for: {vars.join(', ')}
          </div>
        )}
      </div>
    </>
  );
}

Object.assign(window, { QxPinnedEditor, QxEditableArea, QxRunOnPopover, detectVars });
