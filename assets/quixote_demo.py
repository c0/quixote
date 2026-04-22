"""
quixote_demo.py — Manim animation for Quixote macOS app demo
Phone-optimized 9:16 (1080×1920), seamless loop, ~30s at 60fps

Install:
    pip install manim
    brew install ffmpeg font-inter font-jetbrains-mono

Render:
    manim -pqh quixote_demo.py QuixoteDemoScene

Output: media/videos/quixote_demo/1080p60/QuixoteDemoScene.mp4
"""

from manim import *

config.pixel_width  = 1080
config.pixel_height = 1920

# Frame: 4.5 wide × 8.0 tall (9:16 portrait)
FW = 4.5
FH = 8.0

# ── Design tokens (QuixoteTheme.swift) ────────────────────────────────────────
BG           = ManimColor("#171719")
PANEL        = ManimColor("#212124")
PANEL_RAISED = ManimColor("#29292B")
CARD         = ManimColor("#1C1C1F")
DIVIDER      = ManimColor("#3D3D3D")
TEXT_PRI     = ManimColor("#F2F2F5")
TEXT_SEC     = ManimColor("#8F96AD")
TEXT_MUTED   = ManimColor("#6E7382")
SELECTION    = ManimColor("#38383D")
BLUE         = ManimColor("#306BF0")
BLUE_MUTED   = ManimColor("#478CFF")
Q_GREEN      = ManimColor("#38DB7A")

# ── Helpers ───────────────────────────────────────────────────────────────────

def ui(s, size=24, color=TEXT_PRI, weight=NORMAL):
    return Text(s, font="Inter", font_size=size, color=color, weight=weight)

def mono(s, size=22, color=TEXT_PRI):
    return Text(s, font="JetBrains Mono", font_size=size, color=color)

def lbl(s, size=18, color=TEXT_SEC):
    return Text(s.upper(), font="Inter", font_size=size, color=color, weight=BOLD)

def rrect(w, h, r=0.12, fill=PANEL, stroke=DIVIDER, sw=1):
    return RoundedRectangle(
        width=w, height=h, corner_radius=r,
        fill_color=fill, fill_opacity=1,
        stroke_color=stroke, stroke_width=sw,
    )

def chip(s, fill=SELECTION, color=TEXT_PRI):
    txt = mono(s, size=20, color=color)
    bg  = rrect(txt.width + 0.24, txt.height + 0.18, r=0.10, fill=fill)
    return VGroup(bg, txt)

def hdiv_line(card, y_offset, inset=0.16):
    x0 = card.get_left()[0]  + inset
    x1 = card.get_right()[0] - inset
    return Line([x0, y_offset, 0], [x1, y_offset, 0],
                stroke_color=DIVIDER, stroke_width=1)

def nav_dots(n=4, active=0):
    return VGroup(*[
        Circle(radius=0.065,
               fill_color=BLUE if i == active else PANEL_RAISED,
               fill_opacity=1, stroke_width=0)
        for i in range(n)
    ]).arrange(RIGHT, buff=0.16)


# ── Scene ─────────────────────────────────────────────────────────────────────

class QuixoteDemoScene(MovingCameraScene):

    def construct(self):
        self.camera.background_color = BG

        self.dots     = nav_dots(4, 0).move_to([0, -3.65, 0])
        self.step_lbl = mono("STEP 1 OF 4", size=18, color=TEXT_MUTED).move_to([0, 3.65, 0])
        self.add(self.dots, self.step_lbl)

        self._intro()
        self._go(0, "STEP 1 OF 4"); self._drop_file()
        self._go(1, "STEP 2 OF 4"); self._prompts()
        self._go(2, "STEP 3 OF 4"); self._run()
        self._go(3, "STEP 4 OF 4"); self._analytics()

        self.play(FadeOut(*self.mobjects), run_time=1.5)
        self.wait(0.5)

    def _go(self, active, text):
        new_d = nav_dots(4, active).move_to(self.dots.get_center())
        new_l = mono(text, size=18, color=TEXT_MUTED).move_to(self.step_lbl.get_center())
        self.play(Transform(self.dots, new_d), Transform(self.step_lbl, new_l), run_time=0.25)

    # ── Intro ─────────────────────────────────────────────────────────────────
    def _intro(self):
        logo_bg = RoundedRectangle(width=0.70, height=0.70, corner_radius=0.14,
                                   fill_color=BLUE, fill_opacity=1, stroke_width=0)
        logo_q  = ui("Q", size=44, color=WHITE, weight=BOLD)
        logo    = VGroup(logo_bg, logo_q)

        title   = ui("Quixote", size=60, color=TEXT_PRI, weight=BOLD)
        tagline = ui("Batch any data through any LLM.\nPick prompts. Pick models. Get insights.",
                     size=26, color=TEXT_SEC)

        hero = VGroup(logo, title, tagline).arrange(DOWN, buff=0.36)
        hero.move_to([0, 0.15, 0])

        self.play(FadeIn(logo, shift=DOWN * 0.18), run_time=0.45)
        self.play(Write(title), run_time=0.55)
        self.play(FadeIn(tagline, shift=UP * 0.10), run_time=0.50)
        self.wait(1.2)
        self.play(FadeOut(hero), run_time=0.45)

    # ── Phase 1: Drop a file ──────────────────────────────────────────────────
    def _drop_file(self):
        card = rrect(3.90, 5.60, r=0.22, fill=PANEL).move_to([0, 0.30, 0])
        ct   = card.get_top()[1]
        cl   = card.get_left()[0]
        cr   = card.get_right()[0]

        hdr  = ui("Files", size=28, color=TEXT_PRI, weight=BOLD)
        hdr.move_to([cl + 0.25 + hdr.width / 2, ct - 0.50, 0])
        plus = chip("+", fill=PANEL_RAISED, color=TEXT_SEC)
        plus.move_to([cr - 0.42, ct - 0.50, 0])
        div  = hdiv_line(card, ct - 0.90)

        # File row
        icon = RoundedRectangle(width=0.40, height=0.40, corner_radius=0.07,
                                fill_color=PANEL_RAISED, fill_opacity=1,
                                stroke_color=DIVIDER, stroke_width=1)
        fname  = ui("customers.csv", size=24, color=TEXT_PRI, weight=SEMIBOLD)
        fbadge = mono("CSV · 3 COLUMNS", size=17, color=TEXT_MUTED)
        finfo  = VGroup(fname, fbadge).arrange(DOWN, buff=0.08, aligned_edge=LEFT)
        finner = VGroup(icon, finfo).arrange(RIGHT, buff=0.18)
        sel    = rrect(card.width - 0.32, 0.78, r=0.12, fill=SELECTION)
        row    = VGroup(sel, finner)

        row_y  = ct - 1.20
        row.move_to([0, row_y, 0])
        row.shift(LEFT * (row.get_center()[0] + FW + row.width / 2))

        status = mono("LOADED", size=18, color=Q_GREEN).move_to([cr - 0.68, row_y, 0])
        hint   = ui("Drop any CSV, JSON, or Excel\nfile to get started.",
                    size=22, color=TEXT_MUTED).move_to([0, row_y - 1.55, 0])

        self.play(FadeIn(card), run_time=0.32)
        self.play(FadeIn(hdr), FadeIn(plus), Create(div), run_time=0.28)
        self.play(FadeIn(hint), run_time=0.28)

        self.play(row.animate.move_to([0, row_y, 0]),
                  rate_func=rate_functions.ease_out_expo, run_time=0.80)
        self.play(row.animate.shift(RIGHT * 0.09), run_time=0.08)
        self.play(row.animate.shift(LEFT  * 0.09),
                  rate_func=rate_functions.ease_out_sine, run_time=0.12)

        self.play(FadeIn(status, shift=UP * 0.05), run_time=0.25)
        self.wait(1.6)
        self.play(FadeOut(VGroup(card, hdr, plus, div, row, status, hint)), run_time=0.42)

    # ── Phase 2: Prompts & models ──────────────────────────────────────────────
    def _prompts(self):
        card = rrect(3.90, 5.80, r=0.22, fill=PANEL).move_to([0, 0.20, 0])
        ct   = card.get_top()[1]
        cl   = card.get_left()[0]

        hdr  = ui("Prompt Editor", size=26, color=TEXT_PRI, weight=BOLD)
        hdr.move_to([cl + 0.25 + hdr.width / 2, ct - 0.50, 0])
        div  = hdiv_line(card, ct - 0.88)

        # Tabs
        tab1 = VGroup(rrect(1.55, 0.46, r=0.10, fill=SELECTION),
                      ui("Prompt 1", size=22, color=TEXT_PRI, weight=BOLD))
        tab2 = VGroup(rrect(1.55, 0.46, r=0.10, fill=PANEL, sw=0),
                      ui("Prompt 2", size=22, color=TEXT_SEC))
        tabs = VGroup(tab1, tab2).arrange(RIGHT, buff=0.12)
        tabs.move_to([0, ct - 1.22, 0])

        # Template
        tmpl_lbl = lbl("Template", size=18)
        tmpl_lbl.move_to([cl + 0.25 + tmpl_lbl.width / 2, ct - 2.02, 0])
        tmpl_bg  = rrect(card.width - 0.32, 1.35, r=0.12, fill=CARD)
        tmpl_bg.next_to(tmpl_lbl, DOWN, buff=0.14).set_x(0)

        s1 = Text("Analyze ", font="JetBrains Mono", font_size=23, color=TEXT_PRI)
        s2 = Text("{{name}}", font="JetBrains Mono", font_size=23, color=BLUE_MUTED)
        segs = VGroup(s1, s2).arrange(RIGHT, buff=0.0)
        segs.move_to(tmpl_bg).align_to(tmpl_bg, LEFT + UP).shift(RIGHT * 0.18 + DOWN * 0.30)

        # Models
        mlbl  = lbl("Models", size=18)
        mlbl.next_to(tmpl_bg, DOWN, buff=0.40).align_to(tmpl_lbl, LEFT)
        chip1 = chip("GPT-4o")
        chip2 = chip("GPT-4o mini")
        chips = VGroup(chip1, chip2).arrange(RIGHT, buff=0.14)
        chips.next_to(mlbl, DOWN, buff=0.16, aligned_edge=LEFT)

        self.play(FadeIn(card), run_time=0.32)
        self.play(FadeIn(hdr), Create(div), run_time=0.26)
        self.play(FadeIn(tab1, shift=DOWN * 0.06), FadeIn(tab2, shift=DOWN * 0.06), run_time=0.32)
        self.play(Write(tmpl_lbl), Create(tmpl_bg), run_time=0.26)
        self.play(AddTextLetterByLetter(s1, time_per_char=0.048))
        self.play(AddTextLetterByLetter(s2, time_per_char=0.070))
        self.play(Indicate(s2, color=BLUE, scale_factor=1.10), run_time=0.42)
        self.play(Write(mlbl), run_time=0.22)
        self.play(GrowFromCenter(chip1), GrowFromCenter(chip2),
                  lag_ratio=0.40, run_time=0.52,
                  rate_func=rate_functions.ease_out_back)
        self.wait(1.2)
        self.play(FadeOut(VGroup(card, hdr, div, tabs,
                                 tmpl_lbl, tmpl_bg, segs,
                                 mlbl, chips)), run_time=0.42)

    # ── Phase 3: Run ──────────────────────────────────────────────────────────
    def _run(self):
        card = rrect(3.90, 5.70, r=0.22, fill=PANEL).move_to([0, 0.25, 0])
        ct   = card.get_top()[1]
        cl   = card.get_left()[0]
        cr   = card.get_right()[0]

        ds   = ui("customers.csv", size=28, color=TEXT_PRI, weight=BOLD)
        ds.move_to([cl + 0.25 + ds.width / 2, ct - 0.52, 0])
        div  = hdiv_line(card, ct - 0.88)

        run_bg  = rrect(1.80, 0.56, r=0.12, fill=BLUE,
                        stroke=ManimColor("#FFFFFF18"), sw=1)
        run_txt = ui("▶  RUN", size=25, color=WHITE, weight=BOLD)
        run_btn = VGroup(run_bg, run_txt).move_to([0, ct - 1.56, 0])

        # Column headers
        col_y  = ct - 2.38
        lx     = cl + 0.22
        col_bg = Rectangle(width=card.width - 0.24, height=0.40,
                            fill_color=PANEL_RAISED, fill_opacity=1,
                            stroke_width=0).move_to([0, col_y, 0])

        def ch(s, x):
            return mono(s.upper(), size=16, color=TEXT_MUTED).move_to(
                [lx + x, col_y, 0], aligned_edge=LEFT)

        c_num = ch("#",      0.00)
        c_nm  = ch("Name",   0.38)
        c_out = ch("Output", 1.72)
        c_div = Line([lx, col_y - 0.22, 0], [cr - 0.16, col_y - 0.22, 0],
                     stroke_color=DIVIDER, stroke_width=1)

        self.play(FadeIn(card), run_time=0.32)
        self.play(FadeIn(ds), Create(div), run_time=0.26)
        self.play(FadeIn(run_btn), run_time=0.28)

        self.play(run_bg.animate.set_stroke(color=WHITE, width=2.5), run_time=0.14)
        self.play(Flash(run_btn, color=BLUE, flash_radius=0.65, num_lines=10), run_time=0.40)
        self.play(run_bg.animate.set_stroke(color=ManimColor("#FFFFFF18"), width=1), run_time=0.14)
        self.wait(0.16)

        self.play(FadeIn(col_bg), Write(c_num), Write(c_nm), Write(c_out),
                  Create(c_div), run_time=0.26)

        rows     = [("1", "Alice"), ("2", "Bob"), ("3", "Charlie")]
        resps    = ["Positive, engaged", "Neutral tone", "Enthusiastic"]
        row_h    = 0.56
        first_y  = col_y - 0.56
        row_objs = []

        for i, (num, name) in enumerate(rows):
            ry = first_y - i * row_h

            stripe = Rectangle(width=card.width - 0.24, height=row_h,
                                fill_color=PANEL_RAISED,
                                fill_opacity=0.5 if i % 2 else 0,
                                stroke_width=0).move_to([0, ry, 0])
            n_t  = mono(num,  size=18, color=TEXT_MUTED).move_to([lx + 0.12, ry, 0])
            nm_t = ui(name,   size=19, color=TEXT_PRI).move_to([lx + 0.42, ry, 0], aligned_edge=LEFT)
            spin = Arc(radius=0.14, angle=TAU * 0.75,
                       stroke_color=BLUE, stroke_width=2.8)
            spin.move_to([lx + 2.10, ry, 0])
            rdiv = Line([lx, ry - row_h / 2, 0], [cr - 0.16, ry - row_h / 2, 0],
                        stroke_color=DIVIDER, stroke_width=1)

            self.play(FadeIn(stripe), FadeIn(n_t), FadeIn(nm_t), FadeIn(spin), run_time=0.20)
            spin.add_updater(lambda m, dt: m.rotate(TAU * dt * 1.8))
            self.wait(0.48)
            spin.clear_updaters()

            resp = mono(resps[i], size=18, color=TEXT_PRI)
            resp.move_to([lx + 1.72, ry, 0], aligned_edge=LEFT)
            chk  = VGroup(Circle(radius=0.12, fill_color=Q_GREEN,
                                 fill_opacity=1, stroke_width=0),
                          ui("✓", size=16, color=WHITE, weight=BOLD))
            chk.move_to([cr - 0.30, ry, 0])

            self.play(ReplacementTransform(spin, resp),
                      GrowFromCenter(chk), Create(rdiv), run_time=0.33)
            row_objs.extend([stripe, n_t, nm_t, resp, chk, rdiv])

        self.wait(1.2)
        self.play(FadeOut(VGroup(card, ds, div, run_btn,
                                 col_bg, c_num, c_nm, c_out, c_div,
                                 *row_objs)), run_time=0.42)

    # ── Phase 4: Analytics ────────────────────────────────────────────────────
    def _analytics(self):
        card = rrect(3.90, 5.70, r=0.22, fill=PANEL).move_to([0, 0.25, 0])
        ct   = card.get_top()[1]

        hdr  = ui("Analytics", size=32, color=TEXT_PRI, weight=BOLD).move_to([0, ct - 0.54, 0])
        div  = hdiv_line(card, ct - 0.90)

        self.play(FadeIn(card), FadeIn(hdr), Create(div), run_time=0.40)

        tw = (card.width - 0.50) / 2
        th = 1.45

        specs = [
            ("Throughput", "rows/s",  1,  1.4,   TEXT_PRI),
            ("Latency",    "ms p50",  0,  832,   TEXT_PRI),
            ("Tokens",     "in+out",  0,  3200,  BLUE_MUTED),
            ("Cost",       "USD",     4,  0.0082, Q_GREEN),
        ]

        trackers, tiles = [], []
        for label_str, unit_str, decs, end, col in specs:
            bg  = rrect(tw, th, r=0.14, fill=CARD)
            l_t = mono(label_str.upper(), size=16, color=TEXT_MUTED)
            tr  = ValueTracker(0)
            num = DecimalNumber(0, num_decimal_places=decs,
                                font_size=42, color=col)
            num.add_updater(lambda m, t=tr: m.set_value(t.get_value()))
            u_t = mono(unit_str, size=16, color=TEXT_MUTED)
            inner = VGroup(l_t, num, u_t).arrange(DOWN, buff=0.14)
            inner.move_to(bg)
            tiles.append(VGroup(bg, inner))
            trackers.append((tr, end))

        grid = VGroup(
            VGroup(tiles[0], tiles[1]).arrange(RIGHT, buff=0.16),
            VGroup(tiles[2], tiles[3]).arrange(RIGHT, buff=0.16),
        ).arrange(DOWN, buff=0.18)
        grid.move_to([0, ct - 3.28, 0])

        for tile in tiles:
            tile[1].move_to(tile[0])

        self.play(LaggedStart(*[FadeIn(t, shift=UP * 0.08) for t in tiles],
                              lag_ratio=0.18, run_time=0.72))

        self.play(*[tr.animate.set_value(end) for tr, end in trackers],
                  run_time=2.30, rate_func=rate_functions.ease_out_quad)

        for tile in tiles:
            tile[1][1].clear_updaters()

        self.wait(1.5)
        self.play(FadeOut(VGroup(card, hdr, div, grid)), run_time=0.42)
