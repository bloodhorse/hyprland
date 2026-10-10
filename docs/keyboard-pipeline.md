# Keyboard pipeline

How a keypress gets from the Lily58 to a Hyprland action, and why each layer exists.

Current design: **Lily58 (ZMK) → keyd → XKB → Hyprland binds.**

> **State, 2026-10-10.** `configs/keyd/default.conf` is V2.2 and is what runs in
> `/etc/keyd/default.conf`; the Lily58 is attached and keyd grabs it. keyd and Hyprland
> were brought up to the mac's state of that day: `git -C ~/.config/karabiner log` and
> `~/tower/forge/AEROSPACE/aerospace.toml` on the mac are the reference, and
> `docs/mac-hotkeys.md` here is a 2026-08-01 snapshot of them — its key table is stale
> wherever the two disagree. The checks that need fingers are listed at the bottom.

## The layout changed: Gallium, not Colemak-DH

**bekh types Gallium (Colstag) now.** Colemak-DH belongs to the betrayer era. Everything in
the old repos — the keyd `[main]` table, the XKB variant names, the MNEI navigation family,
the keycode mnemonic comments in `hyprland.conf` — was derived from the Colemak-DH home row
and is therefore **prior art, not spec**.

Concretely:

- `hypr-keys/keyd/default.conf` is a **template to rewrite for Gallium**, not a drop-in. Its
  structure is still exactly right (see `[meta]` below — that part is layout-independent);
  its letter table is not.
- The `code:`-based binding trick survives untouched. It maps physical keycodes, so it does
  not care which letters sit where. Only the *mnemonic comments* need redoing.
- `configs/nvim/lua/config/keymaps.lua`, `configs/zed/keymap.json` and
  `configs/tridactyl/tridactylrc` all encode **MNEI** — the four Colemak-DH letters that sit
  on physical HJKL. Under Gallium those positions carry different letters. Treat all three as
  **needs re-derivation against Gallium**, not as blessed carry-overs. The *principle* (one
  navigation quartet, same four physical keys everywhere) is what carries; the letters are
  an implementation detail of the old layout.

### Where Gallium lives — settled 2026-08-01

**In Karabiner.** The Lily58 ZMK firmware sends plain QWERTY positions; the rule
"Gallium Colstag (Lily58 Only)" in `~/.config/karabiner/karabiner.json` does the remap on
the mac. So there is no double-remap risk, and on miniarch **keyd takes Karabiner's role**:
the full Gallium letter table lives in `[main]`.

Done — `configs/keyd/default.conf` in this repo, generated from that karabiner rule, with
the resulting grid drawn in its header. `scripts/02-keyd.sh` installs it.

**Flag carried over from the derivation:** `karabiner.json` still contains a live
"Colemak Mod-DH (Lily58 Only)" rule at index 6, *above* the Gallium rules at 14–16, with the
same device and input-source conditions and no variable gate. Karabiner is documented
first-match-wins top-to-bottom with no chaining, so on paper that stale rule shadows Gallium
for plain letters. It does not affect this repo — the keyd table was derived from the Gallium
rule, which matches published Gallium — but the mac config wants that dead rule deleted.

## Hardware

| device | what it is |
|---|---|
| miniarch | Intel Mac mini 2018, i5-8500B, Intel UHD 630. Arch on linux-t2; headless so far |
| Lily58 Pro | split keyboard, ZMK, Bluetooth — the only keyboard |
| Dell monitor | model TBD; betrayer drove a 2560×1440@60 external at scale 1.667 — verify on first plug |

No internal keyboard, no touchpad, no battery, no backlight. Everything laptop-shaped in the
old configs is dead weight here.

Firmware is deliberately out of scope: the keymap's source of truth is the ZMK Studio
state on the board itself, mirrored to `bloodhorse/zmk-config` (`config/lily58.keymap`,
dumped over Studio RPC). `hypr-keys/inventory/lily58.keymap` is the April 2026 snapshot —
**stale since the 2026-08-01 rework**; read the zmk-config mirror instead.

## What the Lily58 sends

ZMK emits plain evdev codes in **QWERTY positions** — the board knows nothing about
Gallium. The firmware mirror is `bloodhorse/zmk-config`, `config/lily58.keymap`; read it
rather than this table when they disagree. Layers: CURSE = Space held, HEAVEN = Enter
held, shit = either outer thumb, FUCK = either home-row pinky held.

| what | where | what it becomes here |
|---|---|---|
| alt chords | CURSE: every letter seat that is not numpad is `LA(` its own Gallium letter `)`; num row is `LA(ESC)`, `LA(1-4)`, `LA(LG(M))`; `LA(TAB)`, `LA(SPACE)`, `LA(BSPC)` | Hyprland's `$mainMod` binds, untranslated |
| `LGUI` / `RGUI` | inner thumbs | keyd's `[meta]` cmd bridge |
| `LG(1..5)` | FUCK home row | ctrl+1..5, tab switching |
| `LG(LS(3))`, `LG(LS(4))` | FUCK num row | ctrl+shift+3/4 → Hyprland screenshot binds |
| `LG(K)`, `LC(L)` | shit | select-all, ctrl+e |
| `F16` | HEAVEN | launcher |
| `F13` | HEAVEN | nothing yet (the mac's dictation key) |
| `F18` | HEAVEN | switches to Russian — and nothing on the board switches back (no F17) |
| arrows, `Del`, `'`, `` ` `` | HEAVEN / CURSE | pass through |

There is no Alt key on the board at all: no alt-drag with the mouse, and a new alt chord
never needs a firmware cell because CURSE already carries one per letter.

## Layer 1 — keyd (evdev → evdev)

Service: `keyd.service` (system-level). Config: `/etc/keyd/default.conf`, installed from
`configs/keyd/default.conf` by `scripts/02-keyd.sh`.

keyd does three jobs:

1. **The letter layout lives here** — `[main]`, deliberately pulled *out* of XKB so there is
   one remap layer and one place to look. It holds **Gallium Colstag**, generated from the
   karabiner rule. One `[shift]` entry rides along: physical `,` shifts to `\`, not `?`.
2. **No Caps → Esc.** The base layer has no capslock — home-row leftmost is LCTRL and Esc
   has its own key — and since 2026-08-01 the board *can* emit CAPS (CURSE+LShift-position),
   which keyd deliberately passes through as plain capslock. karabiner has no caps remap
   either. The V1.3 line is kept commented in the config so the question is not re-opened
   a third time.
3. **The cmd bridge (V2.1, 2026-08-01).** `[meta]` maps *every* key to
   `Ctrl+<the Gallium letter it types>` — cmd+X on the mac is ctrl+X on Linux, and both
   follow the LETTER (karabiner's "Gallium mod-combos" maps `command+r → command+c`
   because physical R types `c`). Copy/paste/cut/undo/select-all, new tab, close tab,
   find, cmd+1..9 tab switching — the whole cmd-family arrives with mac muscle memory
   intact from the cmd-thumb (LGUI) or RGUI. One exception: `g = M-g`, the mode-c gate,
   passes through as a real Super chord (see hyprland.conf).

4. **The alt namespace (V2.2, 2026-10-10).** `[alt]` is an **identity table**
   (`n = A-n`, every remapped key). The firmware's alt cells already name the letter
   they mean, so an alt chord must pass through untranslated; with an empty `[alt]` it
   fell through `[main]` and was translated a second time, and no letter bind landed.
   Hyprland binds the letter's plain-us `code:`. `[alt+meta]` is the same table for
   alt+cmd chords. Two modifier namespaces, same as the mac: **alt = window manager,
   cmd = app semantics.**
5. **Left shift is its own layer** (`[lshift:S]`) so that shift+6 → `&` and shift+7 → `?`
   are left-shift-only, as the karabiner rules are keyed. The firmware's `&` cell is
   `RS(N7)` and depends on right shift not being rewritten.

`[ids] 1d50:615e` scopes all of it to the Lily58 alone. Since the mini has no built-in
keyboard and the Lily58 is the only board, that scoping is exactly right as written.

**Why every modifier layer spells its keys out** — keyd's layers do not shield unmapped
keys from `[main]`: an unmapped key falls through and picks up Gallium on the way
(upstream architectural limit, keyd issues #705/#752 — full write-up in
`docs/keyd-era-v1/HOW-IT-WORKS.md`). `[meta]` wants Ctrl-translations and `[alt]` wants
identity, so both are written in full. `[control]` is the one that stays empty: there the
fallthrough is the design, ctrl+<physical key> arriving as ctrl+<Gallium letter>.

## Layer 2 — XKB (evdev → keysym)

```ini
input {
    kb_layout = us,ru
    kb_variant = ,
}
```

Plain US and plain ЙЦУКЕН. No layout variant, no hand-written `custom` symbols file — the
letter arrangement is handled below XKB. Layout 0 = English, layout 1 = Russian.

This matters historically: the kanata-era config referenced a `custom` layout with variant
`colemak_dh_q7`, and **that symbols file exists in no repo**. Anyone resurrecting the old
design would hit a hard failure on first boot. The keyd design does not need it.

## Layer 3 — layout switching

```ini
bind = , XF86Launch8, exec, hyprctl switchxkblayout all 0  # F17 → English
bind = , XF86Launch9, exec, hyprctl switchxkblayout all 1  # F18 → Russian
```

Half dead: the firmware sends F18 (HEAVEN) and no F17, so the board can enter Russian and
cannot leave it. Recovery from a terminal or over ssh: `hyprctl switchxkblayout all 0`.
Russian is parked (below), so the toggle is parked with it.

## Layer 4 — Hyprland binds (floating, letter-faithful)

Reconciled against `docs/mac-hotkeys.md` on 2026-08-01 (never yet booted). The model is
the mac's, whole: **floating everywhere** (`float-everything` windowrule), no directional
focus, no tiling verbs — virtual desktops + express lanes + snap grid.

Every bind still uses `code:`, but the codes now mean **the Gallium letter's plain-us
position**, because keyd's empty `[alt]` hands Hyprland the letter, not the physical key.
That keeps binds firing identically on EN and RU *and* keeps the mac's letter mnemonics
true. The letter→code table lives in the hyprland.conf keybindings header.

The bind families (details and per-key comments in `configs/hypr/hyprland.conf`):

- **Express lanes** — `alt-n` zen, `alt-s` chromium, `alt-w` kitty, `alt-z` zed (not
  installed), via `focus-or-launch` (raise-or-cycle through the WM, so the workspace
  always follows — spec §5.1). `alt-tab` is `winswitch`, a fuzzel picker over every window.
- **Workspaces** — `alt-1..0`, `alt-[`/`alt-]` (ws `minus`/`equal`), `alt-esc`, `alt-k`
  (ws `kitty`), `alt-f13..f17`; `alt-shift-<same>` hauls the window and follows.
- **mode c** — Hyprland submap entered by `alt-cmd-m` (the mac's door; CURSE + the 5
  key) or `Super+G`. Haul keys, the `o/h-a-e` snap grid (`configs/bin/snap`), and
  `catchall` so an unbound key *exits* instead of leaking.
- **Verbs** — `alt-v` fullscreen, `alt-x` monitor blackout (dpms), `alt-g` and
  `alt-space` clipboard history, `alt-t` drop-down terminal (special workspace `term`,
  kitty with class `dropterm`), `F16` launcher, `alt-shift-c` screenshot to clipboard,
  ctrl+shift+3/4 screenshot to `~/Pictures/Screenshots`, `ctrl-cmd-esc` click-to-kill,
  `alt-shift-r` reload.

## Full path

```
Lily58 (ZMK, QWERTY positions)
│
├─ letters       → evdev → keyd [main] (Gallium)        → XKB us/ru → application
├─ Cmd+<key>     → evdev → keyd [meta] → Ctrl+<letter>   → XKB      → application  (the bridge)
├─ Alt+<key>     → evdev → keyd [alt] identity           → Hyprland bind on the letter's code:
├─ Alt+Cmd+M     → evdev → keyd [alt+meta] identity      → Hyprland → submap c
├─ Cmd+G         → evdev → keyd [meta] g = M-g           → Hyprland → submap c
└─ Super+Space / Super+Ctrl+Esc / Super+Shift+Esc → keyd (pass) → Hyprland
```

## The unsolved blocker

**Russian under keyd is broken. Parked by bekh on 2026-10-10 — not important on this box.**

Two separate faults:

1. keyd remaps on the Russian layout too. Physical V produces scancode D, which XKB-ru turns
   into `в` instead of the expected `м`. The latin-layout remap has no business running while
   ЙЦУКЕН is active. (Symptom recorded under Colemak-DH; the mechanism is the same for any
   `[main]` letter table, so Gallium inherits it unchanged.)
2. Even if (1) were fixed: on the Russian layout XKB emits Cyrillic keysyms, so Ctrl+C
   arrives as Ctrl+`с` and a lot of applications simply do not react.

Karabiner solves (2) on the mac by switching the input source while Cmd is held. The Linux
equivalent would be rewriting the Russian layout inside keyd and atomically swapping to an
English layer on Cmd/Ctrl-hold. Two V2 sketches sit in `docs/keyd-era-v1/DEPLOYMENT.md`;
neither was attempted.

Worth noting: the same problem existed under keymapper, and under kanata before it. The tool
changed three times; the problem did not. It is a layout-architecture problem, not a tool
problem.

## kanata era (historical)

Everything below is **retired**. keyd replaced it — the two fight over `/dev/input/event*`
and cannot coexist. The config is preserved at `docs/kanata-era/kanata.kbd`.

Under kanata the split of responsibilities was inverted: kanata only handled a handful of
function keys, and **Colemak-DH lived in XKB** (`kb_layout = custom,ru`,
`kb_variant = colemak_dh_q7`). The stated benefit was that the Russian layout stayed pure
ЙЦУКЕН — which is precisely the property keyd lost and has not regained.

kanata mapped four keys and passed everything else through:

```lisp
(defsrc f15 f16 f17 f18)
(deflayer default
  f15 f16 @cpy @pst
)
(defalias
  cpy (multi lctl c)
  pst (multi lctl b)
)
```

**The `lctl b` trick.** kanata sits at the evdev level, *below* XKB, so its key names mean
QWERTY positions. Emitting `lctl v` would send KEY_V, which XKB-Colemak then turns into `d`
— giving the application Ctrl+D. To land on Ctrl+V you have to emit the physical key that
Colemak maps *to* v, which is KEY_B:

| kanata emits | evdev code | XKB Colemak-DH yields | application sees |
|---|---|---|---|
| `lctl c` | KEY_C | `c` | Ctrl+C — copy |
| `lctl b` | KEY_B | `v` | Ctrl+V — paste |
| `lctl v` | KEY_V | `d` | Ctrl+D — wrong |

This inversion is the whole reason the layer-ordering question matters, and it is worth
keeping in mind even though kanata is gone: **whoever remaps last decides what the letter
names mean.**

The pipeline also routed F17/F18 (a dedicated copy/paste pair on the Lily58) through kanata,
while F15/F16 passed through to Hyprland. That produced two parallel copy-paste paths — the
kanata F17/F18 route and the Hyprland `wtype` binds on F15/F16 — which was drift, not design.
Only the Hyprland side survives in the current config.

Also dead from that era: **Toshy** (installed under `~/.config/toshy/`, all services
disabled, never participated) and the X11 keyboard config at
`/etc/X11/xorg.conf.d/00-keyboard.conf` (irrelevant under Wayland).

## Drift found in the old documentation

Recorded so the same corrections do not have to be made twice. The previous README claimed:

- layout switching on `XF86Launch6/7` — the config has always used **Launch8/9**;
- `kb_layout = us,ru` with `kb_variant = colemak_dh_ortho` — the config had
  `custom,ru` / `colemak_dh_q7`, referencing a symbols file that exists nowhere;
- a single copy-paste path — there were in fact two, as described above.

## Not yet pressed by hand

Everything from 2026-10-10 was verified by `keyd check`, the keyd journal,
`hyprctl configerrors` and `hyprctl binds` — not by fingers. Still to press:

- an alt+letter lane (`alt-n`, `alt-w`) and `alt-1..4`
- `alt-cmd-m` then a snap key
- cmd+c / cmd+v, and a FUCK-layer cmd+digit in a browser
- left-shift+7 → `?`, left-shift+6 → `&`, the shit layer's `&` cell
- `alt-t`: whether the drop-down opens at the size the `dropterm` rule asks for
- the window class zen reports (`hyprctl clients | grep class`) against the `zen` regex
