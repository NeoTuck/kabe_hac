---
name: storyboard-director
description: Plan original animated stories from a visual reference profile, including timed shots, character actions, lighting, camera, layered storyboards, and neural audio casting.
---
# Storyboard Director

## 1. Process
1. **Visual Style Planning:** Establish an authentic graphic novel / cinematic noir aesthetic. Specify whether each scene uses Tier 1 (AI-illustrated atmospheric plates + animated overlays) or Tier 2 (Chiaroscuro vector graphics). Primitive vector coder-art is strictly banned.
2. **Concept & Narrative Hook:** Develop an original concept with an immediate 0–3s disruption, escalating mystery, and an existential twist.
3. **Target Specifications:** 30–55 seconds, 9:16 vertical (1080x1920), 30 FPS. Sequence acts with integer start/end frames covering total duration without unintended gaps.
4. **Shot Breakdown:** For EACH shot specify:
   - Duration & exact frame window.
   - Background & environment assets (illustrated plates, lighting cones, atmospheric effects).
   - Character entry/exit pose, two-bone IK actions, anticipation, contact, settle.
   - Facial expression morphs (fear dilation, eye blinks, parted mouth).
   - Props and interaction states (e.g. cassette deck, jammed buttons, telephone handset).
   - Camera motion (push-in, lateral pan, Dutch tilt, depth blur).
5. **Neural Audio & Voice Direction:**
   - Script dialogue with multi-character voice casting.
   - Assign male lead/narrator to `tr-TR-AhmetNeural`.
   - Assign female/child roles to `tr-TR-EmelNeural`.
   - Mark sound effects (foley ka-chunk, radio bandpass filter, heartbeat, silence pause, sub-bass drop).

## 2. Anti-Slideshow & Staging Checks
- Every scene must have physically articulated character motion, secondary props, or environmental animation. Simply zooming a static image is not permitted.
- In a single-actor 9:16 short, character height occupies 20–30% of screen height in wide shots, and 50–70% in close-ups.
- Keep floor horizons grounded and consistent across scene cuts.
