# hyprland

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

As of 2026-10-10 this is the mini's live desktop, not a plan: `~/.config/hypr`, `rofi`,
`fuzzel`, `~/.config/keyd/app.conf` and the scripts in `~/.local/bin` are symlinks into
this repo, and `/etc/keyd/default.conf` is a copy of `configs/keyd/default.conf`.

- Hyprland 0.56.2. Its config format (hyprlang) is deprecated since 0.55 and will be
  dropped; the move to Lua is owed and not started. Do not upgrade Hyprland before it.
- The keyboard path is `docs/keyboard-pipeline.md`; read it before touching keyd or a bind.
- `docs/mac-hotkeys.md` is the 2026-08-01 snapshot of the mac's binds. The mac itself
  (`~/.config/karabiner`, `~/tower/forge/AEROSPACE`) is the reference where they disagree.
- kitty is not here: `~/.config/kitty` is a clone of `bloodhorse/kitty`, the mac is its
  source. `nvim`, `zed` and `tridactyl` under `configs/` are old copies built on the
  Colemak-DH navigation keys and have not been re-derived for Gallium.
- Russian input is broken under keyd and parked.

Four older repos were folded in or retired on 2026-10-10 and have no local copies:
`hypr-keys`, `mac-bin`, `ags-dashboard`, `quickshell-bar` (all archived under
`bloodhorse/` on GitHub). The two `hypr-keys` documents still worth reading live in
`docs/keyd-era-v1/`; any other path here that names one of the four points at its archive.

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
