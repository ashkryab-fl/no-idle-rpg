# Читання під час сидячого відпочинку

Основні референси: `art/hero/reference/{front,back,side}.png`.
Поза, пропорції голови, посадка ніг та плащ: `art/hero/seated_v1/source-seated.png`.
Спільний кадр входу та виходу: `assets/characters/hero/seated.png`.

## Розкадровка

Згенеровано 8 унікальних поз. Меча, піхов і точильного каменя в них немає.
Героїня дивиться вниз на книжку; ліва рука підтримує її, права перегортає
одну сторінку справа наліво відносно глядача.

| Кадр атласу | Дія | Час у кліпі читання |
| --- | --- | --- |
| 0 | Закрита книжка на колінах | 0,18 с, лише під час входу |
| 1 | Відкривання книжки | 0,18 с, лише під час входу |
| 2 | Спокійне читання відкритої книжки | 4,00 с у кожному циклі |
| 3 | Рука бере край сторінки | 0,12 с |
| 4 | Сторінка піднята над корінцем | 0,12 с |
| 5 | Сторінка переноситься вліво | 0,12 с |
| 6 | Рука пригладжує сторінку | 0,12 с |
| 7 | Закрита книжка опускається біля стегна | Лише під час виходу |

Перший прохід: спільна сидяча поза (0,12 с) → 0 → 1 → 2 → 3 → 4 → 5 → 6.
Далі повторюється тільки **2 → 3 → 4 → 5 → 6**, без повторного відкривання.
Тривалість циклу — **4,48 с**: пауза читання 4 с і перегортання 0,48 с.
Пауза задана тривалістю кадру, дублювати його в PNG не потрібно.

## Граф і вихід

`rest.sit → rest.sitHold → rest.activitySelect` обирає `rest.sharpen` або
`rest.read` з однаковими вагами: 50/50. Новий вибір відбувається при кожному
вході після сідання; протягом одного відпочинку активність не змінюється.
Два однакові вибори поспіль дозволені.

Коли повертається активність користувача під час чотирисекундної паузи,
читання одразу переходить до `rest.readCleanup`. Під час перегортання
завершується лише поточне перегортання (до 0,48 с), без очікування наступної
паузи; під час відкривання книга спочатку відкривається.
Кадр 3 таймлайна (кадр 2 атласу) позначений як `interruptibleFrames: [3]`
у варіанті читання з політикою `afterCycle`.
`rest.readCleanup` програє кадри 2 (0,12 с) → 1 (0,16 с) →
0 (0,16 с) → 7 (0,18 с) → спільна сидяча поза (0,12 с).
Далі наявні `rest.exitHold` (0,3 с) та `rest.stand` (1,5 с).
Пригода залишається заблокованою до завершення вставання. У спільній
нейтральній позі меч знову видимий; усі власні кадри книжкової активності
без меча. Раннє повернення під час сідання пропускає вибір активності.

## Артефакти й пакування

- Оригінал генерації: `art/hero/read_v1/source-sheet.png`, RGBA, 1774×887, 4×2.
- Підготовлений source: `art/hero/read_v1/source-ready.png`; прибрано лише
  майже невидимий шум із alpha < 8/255, решта RGBA-пікселів збережена.
- Рецепт: `tool/sprite_assets/manifests/hero/read_v1.json`.
- Ігровий атлас: `assets/characters/hero/read.png`, RGBA, 4096×512,
  8 комірок по 512×512.
- Тимчасові кадри та GIF: `build/sprite_frames/hero/read_v1/` і
  `build/animation_previews/hero/read_v1/`.

Поля додано через наявний `ffmpeg`-конвеєр: crop → спільний масштаб 0,56 →
прозорий pad. Рецепт компенсує положення нижнього ряду й відмінні межі
комірок; позиції вирівняні за нерухомими наколінниками. Прозорі проміжки
визначені за вихідними пікселями. Малюнок не
перегенеровується під час пакування. Геометрія рига така сама, як у сидіння:
anchor (0,5; 0,875), scale 0,25, scaleMultiplier 1,05.

```sh
ffmpeg -v error -y -i art/hero/read_v1/source-sheet.png -vf "lut=a='if(lt(val,8),0,val)'" -frames:v 1 -pix_fmt rgba -update 1 art/hero/read_v1/source-ready.png
python3 tool/sprite_assets/build.py tool/sprite_assets/manifests/hero/read_v1.json
python3 tool/sprite_assets/verify.py tool/sprite_assets/manifests/hero/read_v1.json --previews
flutter test test/content/hero_reading_test.dart
```

## Промпт вибраної генерації

Використано вбудований `image_gen`, `transparent_background: true`; до запиту
прикладені сидячий source, front/back/side T-пози та ігровий `seated.png`.

```text
Use case: stylized-concept
Asset type: production transparent sprite sheet for an existing illustrated 2D anime/chibi game heroine.
Input images: image 1 seated SOURCE pose is the exact composition/pose/identity anchor; images 2 front T pose, 3 back T pose, 4 side views are authoritative character identity/material construction references; image 5 is the installed smaller seated sprite for framing only.
Primary request: create EIGHT successive seated reading animation keyframes, arranged as an exact 4-column x 2-row evenly spaced grid, row major, eight equal square cells. Output 2048x1024 if possible. No labels, gridlines, numbering or text. Genuine transparent alpha everywhere outside the character. Every cell contains ONE full seated heroine with the same head size, compact torso, kneeling/folded legs and boots pointing outward, front-facing very slightly to viewer right, in the EXACT seated arrangement of image 1. Keep the torso, head, ponytail, knees, feet and cape silhouette stationary across all eight cells. Only forearms, gloves, eyes looking down and the book/page change. Same anchor, camera, scale and floor contact in every cell. Each silhouette occupies approximately 88% of its cell width and 74% of cell height, leaving clear empty transparent margins.
Identity: faithfully preserve warm champagne blonde golden-beige ponytail and brown bow with gold/red jewel, large amber eyes, red scarf and tattered spread cape, silver/gold segmented shoulder/forearm/knee/boot armor, gold chest cross, dark brown gloves, belts/pouch and white skirt/red panel. Do not redesign the face or shift towards a different character. Large chibi head from seated source, not a smaller realistic head.
Props: NO SWORD, NO scabbard, NO sharpening stone anywhere in ANY cell. One modest plain brown leather hardcover book with cream pages, no legible text/symbols, centered over her lap, well below her face, held at a slight reading tilt. Her anatomical right hand is on the viewer LEFT. Her anatomical LEFT hand (viewer RIGHT) supports the book throughout page turning.
Frame 1 top-left: same seated legs/cape/head, looking down, CLOSED brown book held horizontally just above lap in both gloved hands; no sword.
Frame 2 top second: book HALF OPEN, covers forming a shallow V, right glove lifting cover; face still looking down, left hand supports it.
Frame 3 top third: relaxed READING baseline, book fully open across lap, cream facing pages visible, both gloves resting naturally on book's lower outer corners, eyes focused down.
Frame 4 top fourth: same open book, right glove (viewer LEFT) reaches diagonally across to the upper viewer-RIGHT page edge to pinch one single cream page; left glove continues supporting book.
Frame 5 bottom-left: right glove lifts THAT ONE page from the viewer-RIGHT leaf, thin cream page curves upward almost vertically above the spine. Book remains still. Left hand supports it.
Frame 6 bottom second: right glove carries the curved single page over the spine towards viewer LEFT, page halfway down on left side, clearly distinct from previous upright page pose.
Frame 7 bottom third: right glove softly smooths the turned page flat on viewer LEFT side; left hand supports book; book now fully open again. Head/body absolutely fixed. This pose must transition smoothly to reading baseline Frame 3.
Frame 8 bottom-right: book CLOSED again and held low beside her anatomical right thigh (viewer LEFT), as she puts the book away; arm extended down modestly, same stationary seated body and cape. No sword yet.
Style: clean shaded illustration matching supplied images exactly, warm fine outlines, softly shaded metal/leather, warm hair highlights. No pixel art, no photorealism, no extra objects, no background, no glow, no platform, no floating shadows. Fully preserve consistent armor details and silhouette. Do not crop any part of hair, cape, boots or hands. Sheet edges and gutters stay transparent.
```
