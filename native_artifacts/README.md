# Native builds and releases

nutdart uses the same build hook for app builds and Kiln release builds. The
supported native targets are `windows-x64`, `windows-arm64`, `linux-x64`,
`linux-arm64`, `macos-arm64`, and `macos-x64` (macOS 12+). Mobile is unsupported
and retains the no-op Dart API; web uses Dart stubs and has no runtime files.

## App builds

Requires Dart 3.10 / Flutter 3.38 or newer. The hook defaults to Kiln's `auto`
mode: download the matching prebuilt library, verify SHA-256, and register a
bundled code asset. If no manifest/target matches the source key, build from
source. A changed C source cannot accidentally use an older prebuilt library.
The generated `@Native` bindings resolve through the asset ID, not a framework
name or a system-library search path.

To require a download or force a source build, add this to the app's pubspec:

```yaml
hooks:
  user_defines:
    nutdart:
      native_build: source # auto (default), source, or download
```

Source builds need CMake and a native C/C++ compiler. Apple builds also need
Xcode; Windows builds need Visual Studio's C++ desktop tools. Linux builds need
`pkg-config libx11-dev libxtst-dev libxinerama-dev libjpeg-dev`. Release Linux
builds use Ubuntu 22.04 for an older glibc baseline. Prebuilts still dynamically
link system libraries: Linux needs X11, Xtst, Xinerama and libjpeg at runtime;
Wayland portal use additionally needs the desktop portals, PipeWire and
libxkbcommon. Installing prebuilts does not grant desktop permissions.

The old Flutter platform-plugin/SPM projects are no longer used: the hook
bundles the library for Flutter and Dart. Do not restore a podspec or add the
old framework manually. Missing desktop assets now fail rather than silently
turning automation calls into no-ops.

## CI and release

- `unit.yml`: format, analyze, host tests, native asset loading, no-process-spawn
  invariant and manifest check. Every PR and main/ci branch push.
- `integration.yml`: all six desktop OS/architecture combinations; X11
  automation in Xvfb; Chrome JS/Wasm compilation of both public libraries;
  real headless GNOME portal consent/type/refusal/stop scenarios. Main/ci branch
  pushes, nightly and manual. Desktop tests never type into the runner's real
  desktop; physical input is opt-in only under Xvfb.
- `kiln_release.yml`: the shared Telosnex workflow builds all six targets using
  `hook/build.dart`. `tool/kiln/prepare.dart` installs missing Linux dependencies;
  `test_build.dart` loads the result and resolves every C API symbol (Intel
  macOS runs on the Intel integration runner, not the ARM64 cross-build host).
- `kiln_check.yml`: the shared manifest/source-key/URL check, nightly and on
  manifest PRs. Renovate keeps SHA-pinned shared workflows/actions current.

Push to `kiln-release-dry` to validate release builds without publishing:

```sh
git push origin HEAD:kiln-release-dry
```

Push to `kiln-release` (or dispatch with `dry_run: false`) to publish the native
files on an immutable `native-<source-key>` GitHub release. The workflow pushes
`kiln-manifest/<tag>` with `prebuilt.json`. Review/merge that branch, then run:

```sh
dart run kiln:check --download
```

Do not publish a new pub.dev version without a matching manifest. Set the
pubspec version *before* the native release: pubspec.yaml is in the source key.
Do not edit the manifest by hand or check binaries into git.

A local release build (no upload):

```sh
dart run kiln:build --target macos-arm64 \
  --out /tmp/nutdart-kiln/out/macos-arm64 --repo Telosnex/nutdart --macos-version 12
TARGET=macos-arm64 OUT=/tmp/nutdart-kiln dart tool/kiln/test_build.dart
```

Ordinary `flutter test` resolves all native asset symbols without moving the
mouse, typing, or requesting screen-recording permission. For physical input
checks, use a disposable desktop explicitly:

```sh
NUTDART_AUTOMATION_TESTS=1 xvfb-run -a flutter test test/nutdart_test.dart
```

`dev/demo.dart` is an interactive demo, not an automatically discovered test.
