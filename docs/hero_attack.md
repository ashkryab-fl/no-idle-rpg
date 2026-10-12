# Hero attack

The attack uses five 512×512 RGBA cells, left to right: guard, overhead windup,
impact, follow-through, guard.
First and last cells copy `ready.png` exactly.
Attack, idle and walk share scale `.20` and anchor `(.62, .875)`.
The hero cycle lasts 0.66 seconds; damage remains at 0.35 seconds in impact cell 2.
Windup cell 1 lasts 0.22 seconds; the other cells last 0.11 seconds each.
Enemy attack duration remains 0.6 seconds. The windup has a horizontal packing
calibration of 0.90; its height and ground line are preserved.
The first walk frame defines the matching profile, proportions and palette.

Sources: `art/hero/attack_v1/source-sheet.png` (windup),
`source-impact.png` and `source-follow.png`.
Recipe: `tool/sprite_assets/manifests/hero/attack_v1.json`.
Runtime: `assets/characters/hero/attack.png`.

```sh
python3 tool/sprite_assets/build_hero_attack.py --no-previews
python3 tool/sprite_assets/build_hero_attack.py --verify
```

## Generation

Built-in `image_gen`, transparent output. The initial motion sheet used the
ready sprite, walk frame 0 and all three canonical design references.
The windup is cropped from an edited sheet using ready and canonical
front/back/side references. Impact and follow-through were generated separately
with ready, walk frame 0 and all three canonical references to retain complete
silhouettes without neighboring artwork. Packing preserves complete figures
and aligns ground contact; the shared guard cells are never regenerated.

<details>
<summary>Windup sheet generation prompt</summary>

```text
Use case: identity-preserve.
Edit target: image 1, a three-cell attack sprite sheet. Image 2 is the authoritative ready sprite; images 3,4,5 are canonical front/back/side design references.
Regenerate the same THREE attack poses from image 1 with corrected cell layout and uncropped anatomy/garments/weapon/effect. Maintain identical character design and proportions matching ready, same right profile, warm champagne ponytail, armor, pouch, sword, painted style.
Output precisely ONE ROW of THREE square cells on an overall 3:1 transparent RGBA sheet, preferably 3072x1024. Each cell is an independent full character with no overlaps. ALL artwork must fit within x=10% to x=90% of its own cell and y=6% to y=90%, leaving FULLY transparent gutters. The existing first cell cape is clipped at the far left and the middle sword slash crosses into third cell: RESTORE complete pointed cape hem and keep EVERY slash pixel inside its own cell. All three figures MUST have exactly the same scale, head size, proportions, foot baseline y=88%, stance midpoint x=58%. Grounded feet approximately x=40% and x=70%. Do NOT enlarge figures to fill the cells. No cropping of cape, hair, boots, sword tips. Leave at least 8% of cell width completely empty between any artwork and vertical cell edges. Separate silhouettes! No alpha at outermost image border.
Cell 1 is overhead windup with two hands holding sword over forehead, blade pointed up-left; complete sword and full left cape are contained. Torso upright, both feet planted.
Cell 2 is impact: slight forward lean, two-handed sword slash blade toward right and slightly down (20deg below horizontal), one thin gold-white arc following overhead/downward swing; reduce arc radius enough to keep it inside this cell. Sword and impact arc never enter another cell. Boots same two grounded contact locations.
Cell 3 is follow-through: torso same slight lean, hands lower forward with sword extending down-right at40degrees. Full sword must fit inside cell. Cape and hair lag left; both boots same grounded locations.
Only correct the spatial layout, margins and missing clipped edges. Preserve poses, heroine, weapon, style and warm palette; keep head size consistent with reference 2. Real transparent background, no checkerboard, ground shadows, text, grid lines or labels. Exactly three poses total.
```

</details>


<details>
<summary>Impact and follow-through generation prompts</summary>

### impact

```text
Use case: identity-preserve. Asset type: ONE single transparent game animation sprite, not a sprite sheet.
References: image1 is the NEW ready guard sprite and defines EXACT identity, art style, proportions, sword and rendering. Image2 is walk frame0: SAME heroine, right-facing profile and scale. Images3,4,5 canonical front/back/side define costume. Preserve exactly same warm champagne high ponytail, brown ruffled hair tie red/gold ornament, amber eyes, fair face in right profile, silver/gold armor gold chest cross, dark gloves, red scarf and tattered cape, brown belts/right hip pouch, ivory skirt red tabard gold emblem, stockings, silver gold boots.
Change only pose for this motion frame. Keep head size, body proportions, weapon length and design IDENTICAL to ready. Single straight silver sword gold guard/red gem/brown handle, TWO natural gloved hands on handle. Maintain same near-side right profile and slight front torso as ready.
Canvas square 1024x1024 actual transparent RGBA. Match ready framing: feet on y=880 (86% height), stance midpoint x=635 (62% width), head center roughly x=650 y=350, top ponytail y=150. BOTH feet planted, rear foot near x=470 and front near x=795. Slight forward weight shift is allowed; no jumping, walking stride or zooming. Full character, hair, cape, sword and effect entirely inside canvas with >=5% transparent margin on ALL edges. No ground or ground shadow, black background, checkerboard, labels, text or watermark. EXACTLY ONE character/pose.
Action: IMPACT of an overhead two-handed diagonal slash toward RIGHT. Torso leans mildly forward from ready, head may lower slightly but keeps same dimensions. Front knee bends, boots keep ground contact and same stance. Hands in front of lower chest, both on same hilt. Blade projects to RIGHT, 20 degrees below horizontal. One SMALL thin pale-gold/white curved slash trail on right shows overhead to down-right swing; keep it within canvas and do not obscure face. Do not draw a second real blade. Cape/ponytail drag left. Blade tip has clear transparent space from right border.
```

### follow

```text
Use case: identity-preserve. Asset type: ONE single transparent game animation sprite, not a sprite sheet.
References: image1 is the NEW ready guard sprite and defines EXACT identity, art style, proportions, sword and rendering. Image2 is walk frame0: SAME heroine, right-facing profile and scale. Images3,4,5 canonical front/back/side define costume. Preserve exactly same warm champagne high ponytail, brown ruffled hair tie red/gold ornament, amber eyes, fair face in right profile, silver/gold armor gold chest cross, dark gloves, red scarf and tattered cape, brown belts/right hip pouch, ivory skirt red tabard gold emblem, stockings, silver gold boots.
Change only pose for this motion frame. Keep head size, body proportions, weapon length and design IDENTICAL to ready. Single straight silver sword gold guard/red gem/brown handle, TWO natural gloved hands on handle. Maintain same near-side right profile and slight front torso as ready.
Canvas square 1024x1024 actual transparent RGBA. Match ready framing: feet on y=880 (86% height), stance midpoint x=635 (62% width), head center roughly x=650 y=350, top ponytail y=150. BOTH feet planted, rear foot near x=470 and front near x=795. Slight forward weight shift is allowed; no jumping, walking stride or zooming. Full character, hair, cape, sword and effect entirely inside canvas with >=5% transparent margin on ALL edges. No ground or ground shadow, black background, checkerboard, labels, text or watermark. EXACTLY ONE character/pose.
Action: FOLLOW-THROUGH immediately after an overhead two-handed slash to RIGHT. Torso leans mildly forward, front knee bent, boots remain planted at ready positions. Both hands lower to in front of waist, naturally gripping same sword. Blade points down-right about40degrees, tip at shin height and well inside canvas. Hair and cape drag left then settle. No slash effect or trail. Do not copy the guard's up-pointing blade; this frame has lowered arms and a clear downward sword.
```

</details>
