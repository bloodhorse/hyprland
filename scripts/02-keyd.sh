#!/usr/bin/env bash
#
# 02-keyd.sh — installs configs/keyd/default.conf to /etc/keyd, enables keyd.service.
#
# WILL: write /etc/keyd/default.conf (after showing you a diff against whatever is
# already there), `systemctl enable --now keyd`, and `keyd reload`. That is a real
# change to how the machine reads a keyboard, so read the next paragraph before running.
#
# WHY IT IS SAFE ANYWAY: the config's [ids] block scopes keyd to 1d50:615e, the Lily58
# alone. Until that board is physically plugged in, keyd grabs no device and remaps
# nothing — you can install this on a headless mini over ssh and the box behaves
# identically. When you do plug the Lily58 in, the emergency stop below applies.
#
# WILL NOT: remove kanata, touch xkb, touch any other unit, or reboot. If a previous
# /etc/keyd/default.conf exists it is backed up, never overwritten in place.
#
# EMERGENCY STOP: Backspace + Escape + Enter together terminates keyd and hands you back
# a plain QWERTY keyboard. Memorise it before plugging the Lily58 in.
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/configs/keyd/default.conf"
DST=/etc/keyd/default.conf
STAMP="$(date +%Y%m%d-%H%M%S)"

echo "==> 02-keyd"
echo
echo "  EMERGENCY STOP: Backspace + Escape + Enter  (terminates keyd)"
echo

if [[ ! -f "$SRC" ]]; then
    echo "  missing: $SRC" >&2
    exit 1
fi

if ! command -v keyd >/dev/null 2>&1; then
    echo "  keyd is not installed. Run scripts/00-packages.sh first (or: paru -S keyd)." >&2
    exit 1
fi

# kanata and keyd fight over /dev/input/event*. Loud, but not fatal on its own — the
# damage only happens if both are running, and that is a service question, not a
# package question.
if pacman -Q kanata >/dev/null 2>&1; then
    echo "  WARNING: kanata is installed. It fights keyd over /dev/input/event*."
    echo "           Make sure its services are dead before the Lily58 goes in."
    echo
fi

# ── the config ─────────────────────────────────────────────────────────
sudo mkdir -p /etc/keyd

copy_needed=1
if sudo test -f "$DST"; then
    # cmp instead of `diff | grep`: a pipeline under `set -o pipefail` turns a normal
    # "files differ" exit into a script abort, and grep -q closing the pipe early gives
    # false negatives on top of that. cmp answers the question directly.
    if sudo cmp -s "$SRC" "$DST"; then
        echo "  ok     $DST already matches the repo — nothing to write"
        copy_needed=0
    else
        echo "  $DST differs from the repo. Diff (< installed, > repo):"
        echo
        # diff exits 1 when files differ, which set -e would treat as failure.
        sudo diff "$DST" "$SRC" || true
        echo
        sudo cp -- "$DST" "$DST.bak.$STAMP"
        echo "  backed up  $DST -> $DST.bak.$STAMP"
    fi
fi

if [[ $copy_needed -eq 1 ]]; then
    sudo install -m 0644 -- "$SRC" "$DST"
    echo "  wrote  $DST"
fi

# ── the service ────────────────────────────────────────────────────────
# enable --now is idempotent: already-enabled and already-running are both no-ops.
sudo systemctl enable --now keyd.service
echo "  ok     keyd.service enabled and running"

# reload picks up the config without dropping the grab on an attached keyboard. It
# fails harmlessly if the daemon is still coming up, so do not let it kill the run.
if sudo keyd reload; then
    echo "  ok     keyd reload"
else
    echo "  note   keyd reload returned non-zero — check: systemctl status keyd"
fi

echo
echo "  layout now in force when the Lily58 is attached (Gallium Colstag):"
echo
echo "      b l d c v   j y o u ,"
echo "      n r t s g   p h a e i"
echo "      x q m w z   k f / ; ."
echo
echo "  copy/paste/cut/undo/select-all sit on the keys that TYPE c/v/x/z/a,"
echo "  i.e. physical R/T/Z/B/K — same as on the mac. Note that this spends"
echo "  physical K (code:45), which hyprland.conf uses for focus-up."
echo
echo "  Russian input under keyd is still broken — see docs/keyboard-pipeline.md."
echo
echo "  EMERGENCY STOP, once more: Backspace + Escape + Enter."
echo "==> 02-keyd: done"
