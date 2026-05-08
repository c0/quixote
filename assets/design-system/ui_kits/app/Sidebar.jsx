// Sidebar — DATA (files) + PROMPTS (pinned). Mirrors SidebarView.swift.

function QxSidebar({
  files, prompts,
  selection, // { kind: 'data' | 'prompt', id }
  onSelect, onAddFile, onAddPrompt,
  brand = 'Quixote', brandSrc,
}) {
  return (
    <aside style={{
      width: 232, flex: 'none',
      display: 'flex', flexDirection: 'column',
      background: QX.panel,
      borderRight: `1px solid ${QX.divider}`,
      color: QX.fg1,
      fontFamily: QX.fontSans,
    }}>
      {/* Header */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 10,
        padding: '12px 14px 10px',
      }}>
        {brandSrc
          ? <img src={brandSrc} alt="" width={24} height={24} style={{ borderRadius: 4, display: 'block' }} />
          : <div style={{ width: 24, height: 24, borderRadius: 4, background: '#000',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontFamily: QX.fontSans, fontSize: 13, fontWeight: 700, color: '#fff' }}>Q</div>}
        <div style={{ fontSize: 15, fontWeight: 700, color: QX.fg1 }}>{brand}</div>
        <div style={{ flex: 1 }} />
      </div>
      <QxRowDivider />

      {/* Scrolling body holds both sections */}
      <div style={{ flex: 1, overflow: 'auto' }}>
        <QxSidebarSection
          label="Data"
          onAdd={onAddFile}
          addTitle="Open a file (⌘O)"
        >
          {files.map(f => (
            <QxSidebarRow
              key={f.id}
              icon="table-2"
              label={f.name}
              status={f.status}
              selected={selection?.kind === 'data' && selection?.id === f.id}
              onClick={() => onSelect?.({ kind: 'data', id: f.id })}
            />
          ))}
        </QxSidebarSection>

        <QxSidebarSection
          label="Prompts"
          onAdd={onAddPrompt}
          addTitle="New pinned prompt (⌘⇧P)"
          topDivider
        >
          {prompts.length === 0 && (
            <div style={{
              padding: '6px 10px 4px', fontSize: 11, color: QX.fg3,
              fontFamily: QX.fontSans,
            }}>
              No pinned prompts. Pin from any prompt tab to save it here.
            </div>
          )}
          {prompts.map(p => (
            <QxSidebarRow
              key={p.id}
              icon="align-left"
              iconColor={QX.fg2}
              label={p.name}
              selected={selection?.kind === 'prompt' && selection?.id === p.id}
              onClick={() => onSelect?.({ kind: 'prompt', id: p.id })}
            />
          ))}
        </QxSidebarSection>
      </div>
    </aside>
  );
}

function QxSidebarSection({ label, onAdd, addTitle, topDivider, children }) {
  return (
    <div>
      {topDivider && <div style={{ height: 1, background: QX.divider, margin: '4px 0' }} />}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        padding: '12px 14px 6px',
      }}>
        <div style={{
          fontFamily: QX.fontSans, fontSize: 10, fontWeight: 700,
          letterSpacing: '0.22em', textTransform: 'uppercase', color: QX.fg3,
        }}>{label}</div>
        <div style={{ flex: 1 }} />
        {onAdd && (
          <button onClick={onAdd} title={addTitle} style={{
            width: 20, height: 20, display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            background: 'transparent', border: 'none', borderRadius: 4, cursor: 'pointer',
            color: QX.fg2,
          }}>
            <QxIcon name="plus" size={13} />
          </button>
        )}
      </div>
      <div style={{ padding: '0 8px 6px' }}>
        {children}
      </div>
    </div>
  );
}

function QxSidebarRow({ icon, iconColor, label, status, meta, selected, onClick }) {
  return (
    <button
      onClick={onClick}
      style={{
        display: 'flex', alignItems: 'center', gap: 10, width: '100%',
        padding: '7px 10px',
        background: selected ? QX.selection : 'transparent',
        border: `1px solid ${selected ? QX.divider : 'transparent'}`,
        borderRadius: 6, marginBottom: 3,
        color: QX.fg1, textAlign: 'left', cursor: 'pointer',
        fontFamily: QX.fontSans,
      }}
    >
      <div style={{ width: 16, display: 'flex', justifyContent: 'center', color: iconColor || QX.fg2 }}>
        <QxIcon name={icon} size={13} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 12, fontWeight: 600, color: QX.fg1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
          {label}
        </div>
        {status && (
          <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: '0.12em', textTransform: 'uppercase', color: QX.fg3, marginTop: 3 }}>
            {status}
          </div>
        )}
      </div>
      {meta && (
        <div style={{
          fontFamily: QX.fontMono, fontSize: 9, fontWeight: 600,
          letterSpacing: '0.16em', color: QX.fg3,
        }}>{meta}</div>
      )}
    </button>
  );
}

Object.assign(window, { QxSidebar, QxSidebarRow, QxSidebarSection });
