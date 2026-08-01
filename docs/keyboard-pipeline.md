# Keyboard pipeline

How a keypress gets from the Lily58 to a Hyprland action, and why each layer exists.

Current design: **Lily58 (ZMK) → keyd → XKB → Hyprland binds.**

> **State warning.** keyd V1.3 shipped and ran on betrayer, the dead laptop. Its config and
> deployment notes live in the `hypr-keys` repo, not here. The post-keyd `hyprland.conf` was
> never committed — the bind table in `hypr-keys/keyd/DEPLOYMENT.md` is the only surviving
> spec of that era. The binds in `configs/hypr/hyprland.conf` in *this* repo are the older
> kanata-era snapshot and have not yet been reconciled with it.

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

### Open question — where does Gallium actually live?

Unresolved, and it decides how much keyd has to do on the mini:

1. **In the Lily58 ZMK firmware** — then the board already emits Gallium positions and keyd
   needs no letter remap at all, only the `[meta]` mac-modifier work.
2. **In the macOS input source** — then it is a mac-side setting with no Linux counterpart,
   and keyd has to reproduce the whole layout.
3. **In Karabiner** — same as (2) for practical purposes, but `karabiner.json` becomes the
   ground truth to translate from.

Answer this before writing a single line of the new keyd `[main]`. Rewriting a layout that
the firmware is already applying gets you a double remap, which is exactly the class of bug
that ate the kanata era.

## Hardware

| device | what it is |
|---|---|
| miniarch | Intel Mac mini 2018, i5-8500B, Intel UHD 630. Arch on linux-t2; headless so far |
| Lily58 Pro | split keyboard, ZMK, Bluetooth — the only keyboard |
| Dell monitor | model TBD; betrayer drove a 2560×1440@60 external at scale 1.667 — verify on first plug |

No internal keyboard, no touchpad, no battery, no backlight. Everything laptop-shaped in the
old configs is dead weight here.

Firmware is deliberately out of scope: the Lily58 ZMK keymap is its own project
(`lily58-zmk`) and never enters this repo. `hypr-keys/inventory/lily58.keymap` is a snapshot
for reading, not a build input.

## What the Lily58 sends

ZMK emits plain evdev codes in **QWERTY positions** — the board knows nothing about
Colemak-DH. On top of that it sends a few specials:

| key | purpose |
|---|---|
| `XF86Launch8` | switch to English |
| `XF86Launch9` | switch to Russian |
| `F15` / `F16` | copy / paste (handled in Hyprland, see below) |

## Layer 1 — keyd (evdev → evdev)

Service: `keyd.service` (system-level). Config: `/etc/keyd/default.conf`, sourced from
`hypr-keys/keyd/default.conf`.

keyd does three jobs:

1. **The letter layout lives here** — `[main]`, deliberately pulled *out* of XKB so there is
   one remap layer and one place to look. The shipped config holds **Colemak-DH**; the mini
   needs **Gallium**, and whether keyd should remap at all depends on the open question
   above. Rewrite this section; do not copy it.
2. **Caps → Esc.**
3. **Mac modifier semantics.** `[meta]` maps Cmd+C/V/X/Z/A onto Ctrl+C/V/X/Z/A, and maps
   every other letter explicitly to `M-<qwerty-letter>` so Hyprland's `Super+<letter>` binds
   see physical positions.

`[ids] 1d50:615e` scopes all of it to the Lily58 alone. Since the mini has no built-in
keyboard and the Lily58 is the only board, that scoping is exactly right as written.

**Why all 26 letters are spelled out in `[meta]`** — the short version: `[meta:M]` alone does
not work. Unmapped keys in a layer fall through to `[main]`, pick up the Colemak remap on the
way, and arrive at Hyprland as the wrong bind (physical F opened a terminal instead of going
fullscreen). This is an upstream architectural limit, not a config mistake. Full write-up:
`hypr-keys/keyd/HOW-IT-WORKS.md`, summarised in [lessons.md](lessons.md).

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
bind = , XF86Launch8, exec, hyprctl switchxkblayout all 0  # English
bind = , XF86Launch9, exec, hyprctl switchxkblayout all 1  # Russian
```

Deterministic, not a toggle: one key means one layout, always. You never have to look at an
indicator to know what you are about to type. keyd passes `XF86Launch8/9` through untouched.

## Layer 4 — Hyprland binds (tiling)

Every bind uses `code:` (raw XKB keycode = evdev code + 8) instead of a keysym, so it fires
identically on EN and RU. This is the load-bearing trick of the whole scheme, it is
hardware-agnostic, and — crucially — it is **layout-agnostic too**: the Colemak-DH → Gallium
switch does not invalidate a single bind. It only invalidates the comments.

The mnemonic table in `configs/hypr/hyprland.conf` still reads Colemak-DH:

```
# Phys. QWERTY:  a  s  d  f  g    h  j  k  l  ;
# Colemak-DH:    a  r  s  t  g    m  n  e  i  o
# XKB keycode:  38 39 40 41 42   43 44 45 46 47
```

**Redo this table for Gallium** when the layout question is settled. Until then it tells you
what the keycodes did on betrayer, which is history, not instructions.

Navigation is **MNEI** — the four Colemak-DH letters that sat on physical HJKL. The mnemonic
is dead under Gallium; the *principle* is not. What actually matters is that one physical
quartet drives navigation in Hyprland, nvim, zed and tridactyl alike. Re-derive the letters,
keep the physical positions (43/44/45/46) unless there is a reason to move them.

| modifier | code:43 | code:44 | code:45 | code:46 |
|---|---|---|---|---|
| Super | focus left | focus down | focus up | focus right |
| Super+Shift | move left | move down | move up | move right |
| Super+Ctrl | resize ← | resize ↓ | resize ↑ | resize → |

Arrow keys work as a fallback. Workspaces are `Super + code:10–19` (1–0), `Super+Shift` to
move a window there, `Super+scroll` to cycle. Mouse: `Super+LMB` drag, `Super+RMB` resize.

The window-management verbs themselves (`Super+F` = terminal? fullscreen?) are exactly the
part that differs between the kanata-era snapshot and the keyd-era table. Do not trust the
current file — reconcile against `mac-hotkeys.md` first.

## Full path

```
Lily58 (ZMK, QWERTY positions)
│
├─ letters      → evdev → keyd [main] (layout)   → XKB us/ru → application
├─ Cmd+C/V/X/Z/A→ evdev → keyd [meta] → Ctrl+…    → XKB      → application
├─ Cmd+<letter> → evdev → keyd [meta] M-<qwerty>  → Hyprland bind
├─ XF86Launch8/9→ evdev → keyd (pass)             → Hyprland → switchxkblayout
└─ Super+code:XX→                                    Hyprland bind (layout-independent)
```

## The unsolved blocker

**Russian under keyd is broken, and it is the one thing keeping this off daily-driver duty.**

Two separate faults:

1. keyd remaps on the Russian layout too. Physical V produces scancode D, which XKB-ru turns
   into `в` instead of the expected `м`. The latin-layout remap has no business running while
   ЙЦУКЕН is active. (Symptom recorded under Colemak-DH; the mechanism is the same for any
   `[main]` letter table, so Gallium inherits it unchanged.)
2. Even if (1) were fixed: on the Russian layout XKB emits Cyrillic keysyms, so Ctrl+C
   arrives as Ctrl+`с` and a lot of applications simply do not react.

Karabiner solves (2) on the mac by switching the input source while Cmd is held. The Linux
equivalent would be rewriting the Russian layout inside keyd and atomically swapping to an
English layer on Cmd/Ctrl-hold. Two V2 sketches sit in `hypr-keys/keyd/DEPLOYMENT.md`;
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
