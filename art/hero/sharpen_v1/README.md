# Seated sword sharpening

The heroine faces the camera and moves a whetstone along the sword lying on
her lap. `source-sheet.png` preserves the original generated 2×2 pose sheet.
`aligned_sources/` contains the installed poses, composited in PhotoCraft with
one canonical stationary body and a separate moving arm. The head, knees,
ground contact and stationary sword pixels are shared across active poses.

`sharpen.png` is a 4608×512 RGBA sheet with nine frames at 0.225 s/frame:
shared seated reference, middle, left intermediate, near guard, left
intermediate, middle, right intermediate, near tip, right intermediate.
Frame 0 is copied from `../seated_v1/reference.png` and played once. Frames
1–8 repeat via `loopStartFrame: 1`, keeping the stone in hand across cycles.
Both intermediate poses are reused on the return stroke. The final return
to middle is frame 1 of the next cycle, avoiding an extra center hold.

`sharpen-preview.gif` repeats the eight active frames (1.8 s/cycle).
`frames/` contains all nine separate PNGs. The graph selects this continuation
after sit-down and loops until activity returns, without repeating sit-down.

Artwork uses the built-in imagegen tool. `prompt.txt` records pose generation;
`spacing-prompt.txt` records the original layout correction. The two new
intermediate prompts are in `intermediate-prompts.txt`, with raw generation
outputs in `generated_intermediates/`. Original individual frames and overlay
diagnostics remain in `alignment_review/`. The installed sources and exact
shared frame are in `manifest.json`; the timeline lives in Dart.

Rebuild/check: `python3 tool/build_hero_rest.py [--verify]`.
See [random continuations](../../../docs/hero_rest.md).
