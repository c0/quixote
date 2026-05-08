// Marketing site primitives. Deeper black background with dither canvas behind.

const QX_SITE = {
  bg: '#030405',
  panel: 'rgba(10, 12, 16, 0.72)',
  panelStrong: 'rgba(14, 17, 22, 0.86)',
  fg1: '#f3f5f8',
  fg2: '#aeb6c2',
  fg3: '#727b87',
  accent: '#d9e0ea',
  border: 'rgba(255, 255, 255, 0.1)',
  shadow: '0 24px 80px rgba(0, 0, 0, 0.45)',
  fontSans: '"Inter Tight", "SF Pro Display", "SF Pro Text", system-ui, -apple-system, sans-serif',
  fontMono: '"JetBrains Mono", "SF Mono", ui-monospace, Menlo, Consolas, monospace',
};

// Mini Apple logo SVG (used inside the primary Download button)
function QxAppleGlyph({ size = 16, color = 'currentColor' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 814 1000" fill={color} style={{ flex: 'none' }}>
      <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76.5 0-103.7 40.8-165.9 40.8s-105.6-57.8-155.5-127.4c-58.5-81.7-105.3-209-105.3-329.1 0-193.1 125.6-295.7 249.2-295.7 65.7 0 120.5 43.2 161.7 43.2 39.2 0 100.4-45.8 174.5-45.8 28.2 0 129.3 2.6 196.3 99.8zm-135.5-183.1c31.1-36.9 53.1-88.1 53.1-139.3 0-7.1-.6-14.3-1.9-20.1-50.6 1.9-110.8 33.7-147.1 75.8-28.2 32.4-55.1 83.6-55.1 135.5 0 7.8 1.3 15.6 1.9 18.1 3.2.6 8.4 1.3 13.6 1.3 45.4 0 102.5-30.4 135.5-71.3z" />
    </svg>
  );
}

// Pill button — the only button style the site uses.
function QxSiteButton({ variant = 'primary', icon, href = '#', children }) {
  const base = {
    display: 'inline-flex', alignItems: 'center', gap: 8,
    padding: '11px 22px', borderRadius: 999,
    fontSize: '0.95rem', fontWeight: 600, textDecoration: 'none',
    border: '1px solid transparent',
    fontFamily: QX_SITE.fontSans,
    transition: 'transform 160ms ease-out, background-color 160ms ease-out, border-color 160ms ease-out',
  };
  const styles = {
    primary:   { ...base, background: 'rgba(244, 247, 251, 0.94)', color: '#050607' },
    secondary: { ...base, background: 'rgba(255, 255, 255, 0.05)', color: QX_SITE.fg1, borderColor: 'rgba(255,255,255,0.1)' },
  };
  return (
    <a href={href} style={styles[variant] || styles.primary}>
      {icon}
      <span>{children}</span>
    </a>
  );
}

// Dither canvas background — exact port of site/src/components/DitherBackground.astro
function QxDitherBackground() {
  const ref = React.useRef(null);
  React.useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const context = canvas.getContext('2d', { alpha: false });
    const bufferCanvas = document.createElement('canvas');
    const bufferContext = bufferCanvas.getContext('2d', { alpha: false });
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
    const bayer4 = [[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]];
    const palette = [[3,4,5],[10,12,15],[18,21,25],[31,35,40],[52,58,66],[164,171,180]];
    let anim = 0, width = 0, height = 0, cellSize = 2.5, columns = 0, rows = 0;
    let imageData = null, data = null, lastFrameMs = 0;
    const targetFrameMs = 1000 / 12;
    const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
    const smoothstep = (e0, e1, x) => { const t = clamp((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t); };

    function resize() {
      width = canvas.parentElement.clientWidth;
      height = canvas.parentElement.clientHeight;
      cellSize = width < 720 ? 2 : 2.5;
      columns = Math.ceil(width / cellSize);
      rows = Math.ceil(height / cellSize);
      canvas.width = width; canvas.height = height;
      canvas.style.width = width + 'px'; canvas.style.height = height + 'px';
      context.setTransform(1,0,0,1,0,0); context.imageSmoothingEnabled = false;
      bufferCanvas.width = columns; bufferCanvas.height = rows;
      bufferContext.imageSmoothingEnabled = false;
      imageData = bufferContext.createImageData(columns, rows); data = imageData.data;
    }
    function fieldAt(nx, ny, time) {
      const dx = time * 0.009, dy = time * 0.0056;
      const a = Math.sin((ny + dy) * 9.6 + Math.sin((nx + dx * 0.85) * 2.7) * 1.25);
      const b = Math.cos((ny - dy * 0.9) * 7.3 - Math.cos((nx - dx * 0.55) * 3.5) * 1.05);
      const c = Math.sin((ny * 6.4 + nx * 1.55) + time * 0.0064);
      const d = Math.cos((ny * 5.3 - nx * 1.1) - time * 0.0052);
      const lw = Math.sin((nx * 1.4 + ny * 2.2) + time * 0.0038);
      const cw = Math.cos((nx * 2.8 - ny * 1.7) - time * 0.0028);
      const env = smoothstep(0.02, 0.18, ny) * (1 - smoothstep(0.84, 0.99, ny));
      const lift = smoothstep(0.02, 0.95, 1 - Math.abs(nx - 0.56) * 1.18) * 0.06;
      const edge = smoothstep(0.01, 0.9, 1 - Math.abs(nx - 0.5) * 1.56) * 0.04;
      const field = 0.18 + env * 0.16 + a * 0.12 + b * 0.1 + c * 0.08 + d * 0.06 + lw * 0.05 + cw * 0.03 + lift + edge;
      const dxc = (nx - 0.5) / 1.18, dyc = (ny - 0.5) / 1.12;
      const vign = clamp(1 - Math.sqrt(dxc * dxc + dyc * dyc), 0, 1);
      return clamp(field + smoothstep(0.02, 0.98, vign) * 0.08, 0, 1);
    }
    function toneIndex(f, x, y) {
      const threshold = (bayer4[y % 4][x % 4] + 0.5) / 16 - 0.5;
      let idx = Math.round(f * 3.3 + threshold * 0.5);
      idx = clamp(idx, 0, palette.length - 2);
      if (f > 0.975 && ((x + y) % 11 === 0 || bayer4[y % 4][x % 4] === 0)) idx = palette.length - 1;
      return idx;
    }
    function render(ms) {
      if (!reduceMotion.matches && ms - lastFrameMs < targetFrameMs) {
        anim = requestAnimationFrame(render); return;
      }
      lastFrameMs = ms;
      const time = ms * 0.001;
      for (let y = 0; y < rows; y++) {
        for (let x = 0; x < columns; x++) {
          const nx = columns <= 1 ? 0 : x / (columns - 1);
          const ny = rows <= 1 ? 0 : y / (rows - 1);
          const f = fieldAt(nx, ny, time);
          const tone = palette[toneIndex(f, x, y)];
          const off = (y * columns + x) * 4;
          data[off] = tone[0]; data[off+1] = tone[1]; data[off+2] = tone[2]; data[off+3] = 255;
        }
      }
      bufferContext.putImageData(imageData, 0, 0);
      context.clearRect(0, 0, width, height);
      context.drawImage(bufferCanvas, 0, 0, width, height);
      if (!reduceMotion.matches) anim = requestAnimationFrame(render);
    }
    resize(); render(performance.now());
    const onResize = () => { cancelAnimationFrame(anim); resize(); render(performance.now()); };
    window.addEventListener('resize', onResize);
    return () => { window.removeEventListener('resize', onResize); cancelAnimationFrame(anim); };
  }, []);

  return (
    <div aria-hidden="true" style={{
      position: 'fixed', inset: 0, zIndex: 0, pointerEvents: 'none', overflow: 'hidden',
      background: QX_SITE.bg,
    }}>
      <canvas ref={ref} style={{
        position: 'absolute', inset: 0, width: '100%', height: '100%', display: 'block',
        imageRendering: 'pixelated', opacity: 0.98,
      }} />
      <div style={{
        position: 'absolute', inset: 0,
        background:
          'radial-gradient(circle at 52% 46%, rgba(6,7,9,0) 0%, rgba(6,7,9,0.04) 42%, rgba(3,4,5,0.18) 76%, rgba(2,3,4,0.4) 100%),' +
          'linear-gradient(180deg, rgba(3,4,5,0.03) 0%, rgba(3,4,5,0.1) 100%)',
      }} />
    </div>
  );
}

Object.assign(window, { QX_SITE, QxAppleGlyph, QxSiteButton, QxDitherBackground });
