---
name: reference-style-analyzer
description: Analyze user-supplied video references for visual style, real motion grammar, lighting, staging, and pacing; do not copy story. Use before coding reference-inspired animation.
---
# Reference Style Analyzer

## Inputs
Original video(s) provided by user; optional preferences/story. Default focus = visual animation, no voice generation.

## Procedure
1. Locate the actual file; never claim to have watched media that wasn't decoded.
2. Run `python3 scripts/analyze_reference.py <video> --outdir outputs/<reference_id> --step 1.5`. Read `analysis.json` and visual contact sheets. If this script is unavailable, use `ffprobe`/`ffmpeg` to extract frames. The pixel delta is *not* semantic motion tracking.
3. Inspect representative frames, THEN inspect tighter timestamp clusters where motion/reaction/threat changes. Identify and label uncertainty.
4. Separate six categories: rendering style (linework/color), actual animation method (rig/walk/poses), stage/space, camera, light/VFX, pacing and emotional action beats.
5. Distinguish *observed* properties from *inferred* implementation. A flattened video does not prove its original creation tool or whether keyframing was used.
6. Produce `outputs/<id>/style_profile.md` with palette approximations, action taxonomy, motion-language rules, camera grammar, 'do not copy' content constraints, examples of reusable primitives.
7. Explicitly hand off to `storyboard-director` only after profile is grounded. Avoid producing one still image per scene as primary plan.

## Composition and motion evidence (V2 lesson)

- Measure visible subject size in sampled portrait frames (approximate head-to-foot pixels / frame height), floor line, active action band, and negative space. Record the range and timecodes; never confuse a player thumbnail's display size with encoded video dimensions. Confirm the latter with FFprobe.
- Make a tighter contact sheet around walk starts/stops, contacts, and reactions (for example every 0.2–0.5 s), then compare consecutive limb and root positions. Label observed foot plant, body drop, arm gesture, and settling separately from guesses about the original rig.
- Track camera and environment using stable anchors such as roof corners or floor edges. Note whether foreground, architecture, and background shift at different rates. A flattened render does not prove camera implementation.
- Record light source positions, cone boundaries, floor reflections, and how they move relative to the actor and props. Sample palette values only as approximations unless pixels are measured.
- Hand off a list of transferable rules (motion cadence, occupation of frame, depth order, light direction) and a separate exclusion list of story/character/text elements. Include uncertainty and at least one feasible original scene application.

## Output contract
- Source metadata and actual times.
- Timestamped observations, evidence-based.
- Reusable motion grammar vs banned narrative replication.
- Feasible technique: SVG character rigs and deterministic keyframe movements with Remotion; alternative tools only when needed.
- Quality risks and an honest unknowns section.

See `references/reference_01_visual_profile.md` for the supplied reference's initial human-inspected example, not a universal template.
