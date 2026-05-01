// Sidebar — file list pane. Matches SidebarView.swift.
const { useState: useStateSB } = React;

function QxSidebar({ files, selectedId, onSelect, onAdd, brand = 'Quixote', brandSrc }) {
  return (
    <aside style={{
      width: 220, flex: 'none',
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
        <button onClick={onAdd} title="Open a file (⌘O)" style={{
          width: 24, height: 24, display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          background: QX.panelRaised, border: 'none', borderRadius: 6, cursor: 'pointer',
        }}>
          <QxIcon name="plus" size={14} color={QX.fg2} />
        </button>
      </div>
      <QxRowDivider />

      {/* List */}
      <div style={{ flex: 1, overflow: 'auto', padding: '10px 8px' }}>
        {files.map(f => (
          <QxSidebarRow
            key={f.id}
            file={f}
            selected={f.id === selectedId}
            onClick={() => onSelect?.(f.id)}
          />
        ))}
      </div>
    </aside>
  );
}

function QxSidebarRow({ file, selected, onClick }) {
  return (
    <button
      onClick={onClick}
      style={{
        display: 'flex', alignItems: 'center', gap: 10, width: '100%',
        padding: '8px 10px',
        background: selected ? QX.selection : 'transparent',
        border: `1px solid ${selected ? QX.divider : 'transparent'}`,
        borderRadius: 6, marginBottom: 6,
        color: QX.fg1, textAlign: 'left', cursor: 'pointer',
        fontFamily: QX.fontSans,
      }}
    >
      <div style={{ width: 16, display: 'flex', justifyContent: 'center', color: QX.fg2 }}>
        <QxIcon name="table-2" size={13} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 12, fontWeight: 600, color: QX.fg1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
          {file.name}
        </div>
        {file.status && (
          <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: '0.12em', textTransform: 'uppercase', color: QX.fg3, marginTop: 3 }}>
            {file.status}
          </div>
        )}
      </div>
    </button>
  );
}

Object.assign(window, { QxSidebar, QxSidebarRow });
