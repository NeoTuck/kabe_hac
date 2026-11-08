---
name: animation-quality-auditor
description: Inspect actual animated MP4 render for FPS, dimensions, visual art quality, motion consistency, stuck frames, anatomy, lighting, continuity, pacing, audio fidelity, and style reference adherence.
---
# Animation Quality Auditor

## 1. Automated Technical Layer
1. Only inspect files that exist. Run `python3 scripts/qc_video.py <render.mp4> --outdir outputs/<id>_qc --expected-width 1080 --expected-height 1920 --expected-fps 30`.
2. Inspect `qc_report.md` and `qc_metrics.json`. Verify resolution is 1080x1920 (9:16), FPS is 30, and duration matches storyboard.

## 2. Visual Art & Graphic Quality Audit (Strict Standard)
- **Zero Flat Primitive Shapes:** Flag simple raw SVG rectangles, circles, or primitive stick-figure drawings without shading or textures as a **BLOCKING DEFECT**. The artwork must meet Tier 1 (AI-illustrated graphic novel plates + motion compositing) or Tier 2 (Chiaroscuro shaded graphic novel art).
- **Character Rig & Anatomy:** Check joint stability, two-bone IK math, no limb popping or foot slippage.
- **Lighting & Atmosphere:** Conical light beams, volumetric dust motes, realistic reflections on dark floors, and dynamic chiaroscuro shadows.
- **Staging & Framing:** Actor occupies 20–30% of screen height in wide shots, 50–70% in close-ups. Safe text margins observed.

## 3. Audio & Voice Naturalness Audit
- **Pronunciation & Diction Check:** Flag robotic monotone TTS or phonetic glitches (e.g. mispronounced words) as a **BLOCKING RETENTION FAILURE**.
- **Neural Voice Casting:** Confirm voice is authentic Turkish neural dubbing (`tr-TR-AhmetNeural` / `tr-TR-EmelNeural`), with distinct voice processing for special roles (e.g. 1984 police radio or telephone filter).
- **Foley & Sound Design:** Confirm presence of synchronized mechanical foley, tension score, silence before twist, and sub-bass impact.
- **Loudness Compliance:** Must meet -14 LUFS target (±1.5 LUFS).

## 4. Output & Reporting
`qc_report.md`: Document technical findings, visual score, audio fidelity check, and required fixes.
