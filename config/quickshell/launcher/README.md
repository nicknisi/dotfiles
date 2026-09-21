# Launcher

Native Quickshell port of [Keystroke 1.3.0](https://github.com/evindor/keystroke/tree/2d1ab484ed6633a2923364c8a869d18d1eca0246), under the included MIT [LICENSE](LICENSE). `../Launcher.qml` supplies the resident IPC entry point. `../Commons/` and `../Ui/` adapt the upstream components to our existing Theme singleton. Omarchy is not required.

The UI and search bindings remain QML/JavaScript. External helpers and `bin/launcher` use LuaJIT with its built-in system interface and the vendored MIT [Lunajson parser](helpers/vendor/lunajson/README.md). Smart Match uses the compiled Rust engine. The launcher no longer runs Python or needs a Python environment.

Calpad is omitted. The calculator is a single answer row over the upstream arithmetic parser (also used to classify spoken input): `12*34`, `sqrt(2)*pi`, `2^10 % 7`; Enter copies the result. A bare number or word never produces an answer.

## Use

Open with Super+Space. Type an application, open window, desktop command, keybinding, filename, `12*34`, `2m in feet`, `10am in London`, `#ff6644`, `:smile`, or `timer 10m tea`. `~` restricts file search. Clipboard history stays in its own screen and continues to use our existing cliphist text/image/video backend. Super+V remains available separately. Alt+Tab opens the Windows screen: open windows most recently focused first, the current one last, so Enter returns to the previous window; Ctrl+Enter closes the selected one.

Arrow keys, Ctrl+N/P and Tab select results. Enter activates, Ctrl+Enter uses the alternate action, Ctrl+1 through Ctrl+8 activate numbered results, Ctrl+, opens settings, Ctrl+K opens provider settings, and Ctrl+B sets a hotkey for the selected result. Backspace or Left with an empty query goes back. Escape closes. Destructive confirmations default to Cancel.

## Hotkeys from the palette

Select an app, command, screen or existing keybinding and press Ctrl+B, then press the chord. The recorder shows whether it is free, taken by a bind in your Hyprland config, or already used by another palette hotkey (which it then replaces). Enter confirms, Backspace removes the row's current hotkey, Escape cancels. While recording, Hyprland sits in the empty `keystroke-capture` submap defined in `config/hypr/hyprland.lua`, so a taken chord is reported instead of fired; Escape leaves the submap even if the palette is gone. Bare letters, digits and Shift-only chords are refused; function and media keys may stand alone. Digits are written as `code:10` through `code:19`, like `workspaces.lua`.

Each hotkey is one native `hl.bind` in the marked block of `~/.config/hypr/launcher-hotkeys.lua`, sourced by `hyprland.lua`, running `qs ipc call launcher run <provider>/<id>` (also `launcher run …` from a shell). The row is resolved from its provider's catalog and activated as Enter would: a row that confirms still confirms, in the palette; anything else runs without showing it. Only rows a provider can hand back by id can be bound, so files, clipboard entries and calculator answers cannot. Saving writes the file, runs `hyprctl reload`, then `hyprctl configerrors`; an error puts the previous text back and reloads again. Bound rows show their chord on the right, the Hotkeys screen labels them "Palette hotkey" with Ctrl+Enter to unbind, and hand-written lines inside the block are kept.

Tap Super+Space again to dictate while open, or hold it to talk. Copilot dictation keeps its existing hold/latch bindings and direct typing. A passive Quickshell popup shares the launcher's waveform instead of voxtype's GTK popup. The dedicated `config/hypr/launcher-voice.lua` file is sourced by Hyprland. Installing changed voice bindings through settings writes that file only. Reload Hyprland to apply them.

The launcher can also serve shell scripts:

```sh
launcher route files
launcher query 'record region'
launcher run applications/org.mozilla.firefox.desktop
launcher dictate
printf 'One\nTwo\n' | launcher select --prompt 'Choose one'
launcher input --prompt 'Project name'
```

Picker cancellation returns 1, failures return 2. Picker requests use private per-request runtime files. A newer picker cancels the previous one.

## State and optional integrations

Settings live at `$XDG_CONFIG_HOME/quickshell-launcher.json`, or `~/.config/quickshell-launcher.json`. They are hot-reloaded, validated and written atomically. Usage ranking and Codex conversation indexes live under `$XDG_STATE_HOME/keystroke`. Clipboard contents are not added to global or semantic search. Timers survive closing the palette but not restarting Quickshell.

Smart Match checks verified local caches first. Select **Retry Smart Match** in Settings > Matching to download the pinned model and build the Rust engine. Setup uses `cargo` if available, otherwise `mise` installs a user-scoped Rust toolchain. Building requires a C linker. The compiled binary is cached by source fingerprint, so subsequent launches need neither a compiler nor network access. No prebuilt executable is vendored. Matching can be disabled independently, and failed setup leaves normal fuzzy search working. Models and the compiled engine live under `$XDG_DATA_HOME/keystroke/matching`.

Codex uses the current CLI model default and existing login. Quick mode disables local tools and inherited integrations. Agent mode is explicit and keeps scoped approvals. The transport currently supports CLI 0.152.0 and 0.153.0 through 0.153.2. A different version fails visibly until its protocol is verified. No API keys are copied into launcher settings.

Native hotkey execution uses the original callbacks captured while our Hyprland config registers its bindings. The resolver rejects old generations and disabled or removed bindings. Mouse, release, hold and submap-only bindings remain keyboard-only. Unregistered bindings remain visible but disabled. Reload Hyprland after installing this config to enable the registry.

## Extensions

The Extensions screen supports discovery, explicit install/enable, update checks, updates and removal. It accepts `owner/repo`, HTTPS repository URLs and local `file:///` repositories for development. The shipped catalog lists the upstream timer extension. A custom index URL can be set in provider settings.

Extensions install under `$XDG_DATA_HOME/keystroke/extensions`. Installation and enabling require confirmation because QML executes unsandboxed with your permissions. Disabled extensions are not instantiated. Removal revokes their enabled setting but keeps other settings. Dirty checkouts are not overwritten. Updates need a Quickshell restart because its component cache retains existing URLs.

Keystroke API 1 row providers, schemas, pattern boosts and host-themed views are supported. This is not an implementation of every Omarchy shell service. Extensions that call Omarchy-specific scripts or APIs still need a native adaptation. See the [upstream provider contract](https://github.com/evindor/keystroke/blob/2d1ab484ed6633a2923364c8a869d18d1eca0246/docs/providers.md). Emoji data includes its own [Unicode attribution](assets/LICENSE-Unicode.txt).

## Checks

```sh
bash config/quickshell/launcher/tests/check.sh
bash config/quickshell/tests/check.sh
Hyprland --verify-config -c "$PWD/config/hypr/hyprland.lua"
```

The test suite uses isolated homes and fake processes for launches, clipboard, audio, package removal, extensions and Codex turns. Some test drivers still use Python, but production helpers do not. Offscreen host tests substitute a Qt Window for the layer-shell window only in a temporary copy. They do not prove compositor focus, live audio or authenticated assistant behavior. `tests/matching_live.py <prepared-data-dir>` additionally verifies real offline model inference without sending commands to the desktop.
