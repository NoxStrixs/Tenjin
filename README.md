# Tenjin

A personal vocabulary and spaced-repetition app. Qt6 + QML on top of a small
C++23 service layer backed by SQLite (FTS5).

## Quickstart

```bash
./tools/init.sh                         # one-time: add yourself to the docker group
./tools/tool docker-build               # one-time: build dev images (~10 min)

./tools/tool build                      # configure + build (linux/debug)
./tools/tool test                       # run tests
./tools/tool package --target linux     # produce AppImage + .deb
./tools/tool package --target windows   # produce Windows installer + portable ZIP
./tools/tool package --target ios       # emit Xcode project + macOS instructions
```

## Project layout

```
Tenjin/
├── App/                   # main.cpp + Info.plist
├── Service/               # C++ libraries, namespace `Service`
│   ├── DatabaseManager/   # SQLite schema + queries
│   ├── WordService/       # validation + composition over DatabaseManager
│   └── DeckService/       # decks, smart filters, SM-2 review sessions
├── View/                  # QML pages, components, ViewModels
├── tests/                 # GoogleTest
├── benchmarks/            # Google Benchmark
├── packaging/             # per-platform install assets
├── tools/                 # build & dev scripts
│   ├── tool               # the entry point CLI
│   ├── init.sh            # one-time host setup
│   ├── docker/            # Dockerfiles per target + windows helpers
│   └── scripts/           # Python modules behind `tool`
└── cmake/                 # CMake support modules
```

## Targets and configurations

Supported build targets: `linux`, `windows` (cross-compiled via MinGW),
`ios` (configure-only on Linux, archived on macOS).

Configurations: `debug` (with ASan/LSan/UBSan), `debug-tsan` (with TSan only,
mutually exclusive with ASan), and `release`.

Every target × config combination gets its own build directory under
`build/<target>-<config>/`, and `./tools/tool` remembers the last pair so subsequent
commands ("test", "package", "analyze") don't need explicit flags.

## Conventions

- All structs, enums, enum classes, and type aliases carry the `_t` suffix.
- All public headers are reached as `<LibraryName/Header.h>`.
- Service results are `Result_t<T> = std::expected<T, std::string>`.
- Private member fields use the `m_` prefix.
- View models are reached from QML through context properties (`appVM`,
  `reviewVm`), not `QML_ELEMENT` registration — keeps the C++/QML coupling
  unidirectional.

See `.clang-format` and `.clang-tidy` for the formatting and analysis rules.

## Packaging

| Target  | Output                                                                                    |
|---------|-------------------------------------------------------------------------------------------|
| linux   | `Tenjin-<v>-Linux-x86_64.deb`, `Tenjin-linux-x86_64.AppImage`                             |
| windows | `Tenjin-<v>-Setup.exe` (NSIS), `Tenjin-<v>-Windows-x86_64.zip` (portable)                 |
| ios     | `build/ios-release/Tenjin.xcodeproj/` — copy to a Mac and `xcodebuild archive` from there |

The Linux and Windows packagers bundle Qt libs, plugins, and QML modules via
Qt's `qt_generate_deploy_qml_app_script`, so users don't need Qt installed.

## License

MIT — see `LICENSE`.
