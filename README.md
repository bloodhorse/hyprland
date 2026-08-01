# hyprland-terraforming

Terraforming a macOS-shaped Hyprland environment onto **miniarch** — an Intel Mac mini 2018
(i5-8500B, UHD 630) that already runs Arch on the linux-t2 kernel.

The goal is a full functional transfer of the mac: terminal, editor, hotkeys, window
management, packages. Not a clone of the look — a transfer of the *habits*. This machine is
for bekh + Claude projects only: rest and creativity. **No work on it** — no profi repos, no
VPN, no DBA tooling.

## Hard constraints

Two of them, and both are the kind that end a project rather than annoy it.

**1. It is a live server.** navidrome, slskd and jellyfin-server run on it right now.
Nothing here may stop, reconfigure, or uninstall any part of that. Every script is written
to be re-runnable on a machine that is already doing its job.

**2. It is a T2 Mac.** It boots `linux-t2` with `apple-bcm-firmware`, `t2fanrd` and
`apple-t2-audio-config`. Nothing in this repo installs, replaces, or upgrades a kernel,
bootloader or firmware package, and no script runs `pacman -Syu`. `00-packages.sh` has a
hard refuse-list for exactly those names. Wi-Fi, fans and audio all hang off that stack.

Working in our favour: root is btrfs on nvme with **snapper + snap-pac**, so every pacman
transaction gets an automatic pre/post snapshot. There is a rollback.

## Status

Skeleton stage, machine still **headless** — no monitor attached yet. Everything so far is
prep that can be done over ssh. What is real:

- `configs/` — carried over from betrayer (the dead laptop). Machine-specific junk stripped;
  the monitor section is a TODO until the Dell is plugged in and identified.
- `packages/` — first honest pass at what the configs actually need. Most of it is already
  installed; per the 2026-08-01 inventory the only real gaps were **fuzzel** and **keyd**.
  Hyprland on the box is 0.55.4, kitty 0.48.
- `scripts/` + `setup.sh` — provisioning runner, not yet run against the mini.
- Keybinds in `configs/hypr/hyprland.conf` are **kanata-era** and await reconciliation
  against `docs/mac-hotkeys.md` (the mac's AeroSpace/Karabiner semantics, extracted
  separately). They are prior art, not the spec.
- keyd config itself still lives in the `hypr-keys` repo. `scripts/02-keyd.sh` only points
  at it.
- **The layout changed.** bekh types **Gallium (Colstag)** now; Colemak-DH was betrayer. The
  `code:`-based binds survive untouched — they map physical keycodes — but every
  Colemak-derived *mnemonic* is stale, and the keyd `[main]` table is a template to rewrite
  rather than a drop-in. That also puts `nvim`, `zed` and `tridactyl` (all built on the MNEI
  quartet) in the **needs re-derivation** bucket, not the blessed-carry-over one. Details
  and the open question — where Gallium actually lives — in `docs/keyboard-pipeline.md`.

### Expiry date on the config format

Hyprland 0.56.0 landed with no breaking changes from 0.55, but **0.56.1 adds a deprecation
notice for `.conf` configs** — upstream is migrating to Lua. Nothing to do today; we build
`.conf` because that is what runs. Just know that a migration is on the horizon and do not
invest in clever `.conf` metaprogramming that will have to be thrown away.

## Layout

```
configs/       dotfiles, one directory per target under ~/.config
packages/      *.lst — one package per line, # comments, pacman -S --needed consumable
scripts/       numbered, idempotent provisioning steps
setup.sh       runs scripts/ in order
docs/          the knowledge that is not a config file
```

`docs/`:

- `keyboard-pipeline.md` — how a keypress travels from the Lily58 to a Hyprland action.
- `lessons.md` — Hyprland/keyd pain already paid for. Read before debugging.
- `postponed.md` — dashboard/panel work, where the artifacts live.
- `kanata-era/` — the retired kanata config, kept as historical reference.
- `mac-hotkeys.md` — the mac-side hotkey spec the binds get reconciled against.

## How setup.sh works

```bash
./setup.sh          # prints the plan, asks, then runs scripts/ in order
./setup.sh --dry-run  # prints the plan and exits
```

It executes every `scripts/NN-*.sh` in filename order and stops at the first failure. Each
script is independently runnable and safe to re-run:

| script | does |
|---|---|
| `00-packages.sh` | `pacman -S --needed` from `packages/*.lst`; AUR entries are printed, never auto-installed |
| `01-configs.sh` | symlinks `configs/*` into `~/.config`; backs up any existing real file to `*.bak.<ts>` |
| `02-keyd.sh` | stub — prints where the keyd config lives and what to do with it |
| `99-verify.sh` | read-only; prints ✓ / ✗ MISMATCH per package and binary |

No script installs an AUR helper, touches systemd units it did not create, or deletes user
data.

## Decisions already made

Settled in `../TRIAGE.md`, recorded here so nobody re-litigates them:

- **Keyboard: keyd.** kanata is history — see `docs/kanata-era/`.
- **Terminal: kitty.** The ghostty config was discarded.
- **Launcher: fuzzel.** `configs/rofi/config.rasi` survives as a *theme reference only* — it
  was polished but never even wired to a bind, and fuzzel won the pick.
- **Bar: never.** bekh has never used one. Permanently out of scope.
- **Dashboard: postponed.** See `docs/postponed.md`.
