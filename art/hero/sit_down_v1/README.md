# Sit-down entry

`source-sheet.png` contains four generated poses. The first three are packed
using one common scale; the final pose is copied from
`../seated_v1/reference.png` to match all future continuations exactly.

`sit_down.png` is the 2048×512 RGBA runtime sheet, four frames at 0.3 s/frame.
It plays once. `IdleAnimationCatalog` adds a 0.5 s hold after playback, so the
final seated pose is visible for 0.8 s before the next animation starts.

`sit-down-preview.gif` shows the entry and hold. `rest-preview.gif` additionally
shows three sharpening cycles; it restarts the whole sequence for review.
The game stays in sharpening until user activity returns.

`prompt.txt` records the built-in imagegen prompt. `manifest.json` records
only source crops, scale, placement and the shared pose copy. Timelines live in Dart.

Rebuild/check: `python3 tool/build_hero_rest.py [--verify]`.
See [the extension guide](../../../docs/hero_rest.md).
