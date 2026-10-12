# Idle Companion

A small desktop RPG that keeps you company while you work.

Built with **Flutter**, **Flame**, and **Cubit / flutter_bloc**, and **GetIt / Injectable** for **macOS** and **Windows**.
The heroine travels and fights while you are active, then rests when you step away.

## Features

- Transparent desktop overlay with always-on-top and click-through support.
- Automatic combat, five-wave stages, bosses, and revival after defeat.
- Gold for equipment; Knowledge Books for six talents in three alternative pairs.
- Animated heroine, scrolling landscapes, and a seated sword-sharpening rest sequence.
- Activity statistics, opacity controls, and 15/30/60 FPS settings.
- Local saves with backup recovery and saving before exit.

Progress is earned while the app is running. There are no offline rewards.
Activity detection reads idle duration, without recording keystrokes or input contents.

## Quick start

Use a Flutter SDK that includes Dart **3.12+**. Dependencies are pinned in
`pubspec.lock`. Run the following commands from the repository root on the target OS.

### macOS

Requires macOS 12+ and Xcode with command-line tools.

```sh
flutter config --enable-macos-desktop
flutter pub get
flutter run -d macos
```

### Windows

Requires Visual Studio with the **Desktop development with C++** workload
and a Windows SDK.

```powershell
flutter config --enable-windows-desktop
flutter pub get
flutter run -d windows
```

Click the heroine or the menu button to open Equipment, Talents, Statistics,
or Settings. Use **Exit** to save and close the app.

## Development

```sh
# Regenerate dependency registrations after changing DI annotations/constructors:
dart run build_runner build
flutter analyze
flutter test
```

Build a release on the corresponding host:

```sh
flutter build macos --release
# On Windows:
flutter build windows --release
```

## Documentation

| Guide | Contents |
| --- | --- |
| [Architecture](docs/architecture.md) | Directory tree, module responsibilities, and runtime flow |
| [Development tools](tool/README.md) | Sprite tooling entry point |
| [Sprite pipeline](tool/sprite_assets/README.md) | Packing, verification, and source requirements |
| [Hero reference](docs/hero_reference.md) | Character identity and artwork guidance |
| [Sleeping rest](docs/hero_sleep.md) | Four-frame sleep loop and reusable crossfades |

## Contributing

Keep changes focused and describe the behavior they affect. Put game rules in the
domain and simulation layers, and keep native APIs behind platform services.
Run the checks above for code changes; add regression tests for currency arithmetic,
purchases, combat, rewards, or save recovery when those contracts change.

## Project status

This is an in-progress MVP. Windows build and runtime validation are still pending;
its overlay currently uses color-key transparency. Balance is still being tuned.
Audio playback and launch at startup are not implemented.

## License

A `LICENSE` file has not been added yet.
