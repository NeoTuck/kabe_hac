---
name: 2d-motion-producer
description: Build smooth, layered, rigged 2D animations in Remotion, TypeScript and SVG from an original storyboard; use for motion, pose timing, continuity and rendering.
---
# 2D Motion Producer

## 1. Visual Quality Directives (Strict Anti-Primitive Rule)

> **STRICT BAN ON FLAT CODER-ART:** Simple raw SVG rectangles, circles, or primitive stick-figure drawings without shading or textures are strictly forbidden for final deliverables. Every AI creating animation here must produce high-production-value graphic novel or cinematic illustration visuals.

### Two Approved Production Pipelines:

1. **Tier 1: Hybrid AI Illustrated Plates + Remotion Rigging (Recommended for Max Retention):**
   - Use high-resolution, atmospheric 2D graphic novel / anime noir illustrations (1080x1920 9:16) for environments, establishing shots, and key hero props (e.g. via `image-generator` or AI illustration engines).
   - In Remotion, separate foreground, midground, and background into parallax layers (`cameraPanX`, `zoom`, `blur(px)` depth-of-field).
   - Superimpose articulated SVG/Sprite character rigs (twoBone IK, walking, expressive facial features, breathing, gestures) and animated interactive props (spinning tape reels, twitching VU meters, vibrating telephones, cracking wax seals).
   - Add atmospheric overlay passes: dust motes, volumetric lamp light cones, CRT scanlines, and subtle vignette.

2. **Tier 2: High-End Chiaroscuro Graphic-Novel SVG Art (Noir Vector Tier):**
   - If rendering full SVG, employ advanced graphic-novel techniques: multi-tone gradient shading, SVG turbulence grain (`<feTurbulence>`), dynamic drop shadows, rim light edges, textured clothing folds, and expressive facial anatomy with catchlights.

---

## 2. Audio Production Standard (Viral Turkish Dubbing & Foley)

> **NEVER USE FLAT ROBOTIC OR MISPRONOUNCING TTS:** Monotone synthesizers or English-accented models that garble Turkish phonetics (e.g. mispronouncing "kaset" as "kese et") destroy viewer retention within the first 2 seconds.

- **Mandatory Neural Turkish Casting:**
  - **Narrator / Protagonist:** `tr-TR-AhmetNeural` (Deep, commanding, documentary/mystery narrator voice).
  - **Secondary / Female / Mother Roles:** `tr-TR-EmelNeural` (Emotional, natural, authentic female voice).
- **Multi-Character Dialogue & Audio FX:**
  - Apply authentic vintage filters for radio/police tapes or phone lines (`highpass=f=400,lowpass=f=3200`).
  - Enforce a 0.5–0.8s **dead-silence pause** immediately before unexpected narrative twists.
  - Layer procedural foley: mechanical clicks, magnetic tape hum, heartbeat sub-bass, and impact drops.
  - Final mix must be loudnorm-mastered to **-14 LUFS** (Instagram Reels broadcast standard).

---

## 3. Hard Motion & Rigging Rules

- Use `remotion-starter/` as a starting point. Create per-project modular components for rigs, props, environments, lighting, and reflections.
- Use `useCurrentFrame()`, `interpolate()`, `spring()` and frame-based deterministic motion. Avoid CSS timers or browser-time dependencies.
- **Articulated Limbs with Two-Bone IK:** Torso, neck, upper/lower arms, upper/lower legs. Anchors must remain consistent; feet grounded in world space using stance/swing intervals without foot slippage.
- **Face & Eye Expression:** Pupils with catchlights that dilate with shock/fear (`pulse()` blinks, widening eyes, parted lips).
- **Secondary Animation:** Breathing bobs, hair follow-through, fabric sway, smoke wisps, vibrations.
- **Staging:** Single-character portrait framing must occupy 20–30% of screen height (`scale: 1.8 - 2.4x`). Close-ups scale to `2.6x - 3.2x`.

---

## 4. Iterative Production Workflow

1. **Story & Shotlist:** Establish 30–55s duration, 9:16 aspect ratio (1080x1920), 30 FPS.
2. **Audio First Lock:** Generate multi-character neural voiceover (`edge-tts`), mix foley and tension bed, extract Whisper word timestamps.
3. **Visual Asset Generation:** Produce high-res illustrated background plates or stylized Chiaroscuro vector scenes.
4. **Remotion Composition:** Assemble scenes with synchronized timeline sequences, kinetic captions, and camera motion.
5. **Quality Control:** Run automated QC (`python3 scripts/qc_video.py`) to verify 0 errors, 0 dropped frames, and correct aspect ratio.
