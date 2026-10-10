#!/usr/bin/env bash
#
# 01-configs.sh — symlinks configs/* into ~/.config (and bash/.bashrc into ~/.bashrc),
# so editing a file in ~/.config edits the repo. Re-running is a no-op once the links
# point where they should.
#
# WILL NOT: overwrite anything blindly. An existing real file or directory is moved to
# <name>.bak.<timestamp> first — nothing is ever deleted. Only the targets listed in
# TARGETS below are touched; no other part of ~/.config, no system files, no services.
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S)"

# Explicit allow-list rather than a glob: a new directory appearing in configs/ should
# be a deliberate deployment decision, not something a re-run silently picks up.
#
# Caveat on nvim / zed / tridactyl: their keymaps encode the MNEI quartet derived from
# Colemak-DH, and bekh types Gallium now. They deploy fine, they just may bind the
# wrong four keys until re-derived. See docs/keyboard-pipeline.md.
# rofi is deployed as a theme reference only — fuzzel won the launcher pick.
TARGETS=(hypr kitty nvim zed tridactyl rofi fuzzel)

link() {
    local src="$1" dst="$2"

    if [[ ! -e "$src" ]]; then
        echo "  skip   $dst  (no $src)"
        return
    fi

    if [[ -L "$dst" ]]; then
        if [[ "$(readlink "$dst")" == "$src" ]]; then
            echo "  ok     $dst"
            return
        fi
        # Someone else's symlink. Move it aside rather than assume it is ours.
        mv -- "$dst" "$dst.bak.$STAMP"
        echo "  moved  $dst -> $dst.bak.$STAMP  (was a symlink elsewhere)"
    elif [[ -e "$dst" ]]; then
        mv -- "$dst" "$dst.bak.$STAMP"
        echo "  backed up  $dst -> $dst.bak.$STAMP"
    fi

    ln -s -- "$src" "$dst"
    echo "  linked $dst"
}

mkdir -p "$CFG"

echo "==> linking configs into $CFG"
for t in "${TARGETS[@]}"; do
    link "$REPO/configs/$t" "$CFG/$t"
done

# bash is the odd one out: it belongs at ~/.bashrc, not under ~/.config.
echo "==> linking shell config"
link "$REPO/configs/bash/.bashrc" "$HOME/.bashrc"

# Helper scripts the hyprland binds call ($bin = ~/.local/bin in hyprland.conf).
# Linked per-file so unrelated things already living in ~/.local/bin are untouched.
echo "==> linking bin scripts"
mkdir -p "$HOME/.local/bin"
for f in "$REPO"/configs/bin/*; do
    [[ -f "$f" ]] || continue
    chmod +x "$f"
    link "$f" "$HOME/.local/bin/$(basename "$f")"
done

echo "==> 01-configs: done"
echo "    reminder: nothing here restarts Hyprland. Reload it yourself when ready."
