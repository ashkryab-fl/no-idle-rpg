# Canonical seated pose

Use `reference.png` (512×512 RGBA) as the first frame of future seated
activities. `source-reference.png` is the higher-resolution original cell for
image generation. The heroine faces the camera, sits on the ground with her
legs folded, and rests her sword across her lap.

The sit-down final frame, sharpening entry and installed `seated.png` are exact
copies. All use anchor `(0.5, 0.875)`, scale `0.25`, with ground contact at
approximately pixel y=448. Keep head/body scale and position when adding poses.

`source-seated.png` and `prompt.txt` are the initial generated identity study.
The final reference is selected from the neutral pose of the sharpening sheet
to match the animated rig. Artwork uses the built-in imagegen tool.

Rebuild: `python3 tool/build_hero_rest.py`.
See [the rest animation contract](../../../docs/hero_rest.md) for prompts,
branching and previews.
