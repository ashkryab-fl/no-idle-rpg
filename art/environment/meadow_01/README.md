# Meadow background

Generated with the built-in image_gen tool. The selected PNG is
`assets/environment/background_meadow_01.png` (2172 × 724, 3:1).
The generation and seam refinement prompts are saved in `prompt.txt`.

Open `preview.html` to see the repeating panorama and a 400 × 120 game-sized
scrolling preview. The original generation was selected because the refinement
increased boundary differences. Visual inspection of the repeated panorama and
the compact preview found no obvious seam. The boundary pixels are not identical:
the mean RGB difference is 4.09 / 255, versus 2.47 / 255 for neighboring columns
within the image. This is visual continuity, not a guarantee of pixel-identical
boundaries. The PNG is connected to the Flutter renderer as the first segment
of AssetCatalog.backgrounds, followed by the stream and wheat backgrounds.
