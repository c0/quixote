// Prompt editor pane — tabs, MODEL, VARIABLES, SYSTEM MESSAGE, PROMPT.

function QxPromptEditor({
  tabs, activeTabId, onSelectTab, onAddTab, onCloseTab,
  models, columns,
  systemMessage, onSystemMessageChange,
  promptText, onPromptChange,
}) {
  return (
    <section style={{
      width: 440, flex: 'none',
      display: 'flex', flexDirection: 'column',
      background: QX.panelRaised,
      borderRight: `1px solid ${QX.divider}`,
      color: QX.fg1, fontFamily: QX.fontSans,
    }}>
      {/* Tab strip */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '10px 18px', minHeight: 44 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flex: 1, overflow: 'hidden' }}>
          {tabs.map(t => (
            <div
              key={t.id}
              onClick={() => onSelectTab?.(t.id)}
              style={{
                display: 'inline-flex', alignItems: 'center', gap: 8,
                padding: '7px 10px', borderRadius: 6,
                background: t.id === activeTabId ? QX.selection : 'transparent',
                cursor: 'pointer',
              }}
            >
              <span style={{
                fontSize: 12,
                fontWeight: t.id === activeTabId ? 700 : 500,
                color: t.id === activeTabId ? QX.fg1 : QX.fg2,
                whiteSpace: 'nowrap',
              }}>{t.name}</span>
              <span onClick={(e) => { e.stopPropagation(); onCloseTab?.(t.id); }}
                style={{ display: 'inline-flex', alignItems: 'center', cursor: 'pointer' }}>
                <QxIcon name="x" size={9} color={QX.fg2} stroke={2.5} />
              </span>
            </div>
          ))}
        </div>
        <button onClick={onAddTab} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 4 }}>
          <QxIcon name="plus" size={14} color={QX.fg2} />
        </button>
      </div>
      <QxRowDivider />

      {/* Body */}
      <div style={{ flex: 1, overflow: 'auto', padding: '14px 18px' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
          {/* MODEL */}
          <div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
              <QxSectionLabel>Model</QxSectionLabel>
              <QxIcon name="info" size={14} color={QX.fg2} />
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {models.map((m, i) => <QxModelCard key={i} {...m} />)}
            </div>
          </div>

          {/* VARIABLES */}
          <div>
            <QxSectionLabel style={{ marginBottom: 10 }}>Variables</QxSectionLabel>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {columns.map(c => <QxChip key={c} text={c} />)}
              <QxChip text="+ Add" closable={false} muted />
            </div>
          </div>

          {/* SYSTEM MESSAGE */}
          <div>
            <QxSectionLabel style={{ marginBottom: 10 }}>System Message</QxSectionLabel>
            <QxTextArea
              value={systemMessage}
              onChange={onSystemMessageChange}
              placeholder="Describe desired model behavior (tone, tool usage, response style)"
              minHeight={120}
            />
          </div>

          {/* PROMPT */}
          <div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
              <QxSectionLabel>Prompt</QxSectionLabel>
              <QxSegmented options={['Write', 'Preview']} value="Write" />
            </div>
            <QxTextArea value={promptText} onChange={onPromptChange} placeholder="Summarized in 3 bullet points:\n{{body_html}}" minHeight={180} />
          </div>
        </div>
      </div>
    </section>
  );
}

function QxModelCard({ name = 'gpt-4.1', online = true, settings = { temp: '1.00', topP: '1.00', tokens: '2048' } }) {
  return (
    <div style={{
      background: QX.card, border: `1px solid ${QX.divider}`, borderRadius: 6,
      padding: 14, display: 'flex', flexDirection: 'column', gap: 12,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
          <span style={{ fontSize: 16, fontWeight: 700, color: QX.fg1, whiteSpace: 'nowrap' }}>{name}</span>
          {online && <span style={{ width: 7, height: 7, borderRadius: 999, background: QX.green, display: 'inline-block', marginLeft: 2 }} />}
        </div>
        <div style={{ display: 'inline-flex', gap: 10, color: QX.fg2 }}>
          <QxIcon name="sliders-horizontal" size={15} />
          <QxIcon name="trash-2" size={14} />
        </div>
      </div>
      <div style={{ fontFamily: QX.fontMono, fontSize: 11, color: QX.fg2, lineHeight: 1.6 }}>
        text.format: text&nbsp; temp: {settings.temp}&nbsp; tokens: {settings.tokens}<br />
        top_p: {settings.topP}
      </div>
    </div>
  );
}

function QxTextArea({ value = '', onChange, placeholder, minHeight = 120 }) {
  return (
    <div style={{
      background: QX.card, border: `1px solid ${QX.divider}`, borderRadius: 6,
      padding: 12, minHeight,
      fontFamily: QX.fontMono, fontSize: 14, color: QX.fg1,
      whiteSpace: 'pre-wrap',
    }}>
      {value
        ? <span>{value}</span>
        : <span style={{ color: QX.fg3 }}>{placeholder}</span>}
    </div>
  );
}

function QxSegmented({ options, value, onChange }) {
  // options can be ['Write','Preview']  OR  [['write','Write'], ['preview','Preview']]
  const norm = options.map(o => Array.isArray(o) ? o : [o, o]);
  return (
    <div style={{
      display: 'inline-flex', background: QX.panel, borderRadius: 6,
      border: `1px solid ${QX.divider}`, padding: 2,
    }}>
      {norm.map(([v, l]) => (
        <button key={v} onClick={() => onChange?.(v)} style={{
          padding: '4px 12px', fontSize: 11, fontWeight: 600,
          fontFamily: QX.fontSans,
          color: v === value ? QX.fg1 : QX.fg2,
          background: v === value ? QX.blue : 'transparent',
          border: 'none', borderRadius: 4, cursor: onChange ? 'pointer' : 'default',
          letterSpacing: '0.04em',
        }}>{l}</button>
      ))}
    </div>
  );
}

Object.assign(window, { QxPromptEditor, QxModelCard, QxTextArea, QxSegmented });
