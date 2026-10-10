#!/usr/bin/env bash
#
# setup.sh — runs scripts/NN-*.sh in filename order and stops at the first failure.
# Prints the whole plan before doing anything and waits for a yes.
#
# WILL NOT: touch navidrome, slskd or jellyfin-server, or any systemd unit it did not
# create. Will not run a full system upgrade and will not go near the kernel — miniarch
# is a T2 Mac on linux-t2 with apple-bcm-firmware and t2fanrd, and that stack is load-
# bearing for the machine booting at all.
#
# Every step is written to be re-runnable on a machine that is already doing its job.
# Safe to run over ssh, and safe with no monitor attached — nothing here needs a
# Wayland session.
#
#   ./setup.sh            plan, confirm, run
#   ./setup.sh --dry-run  plan only
#   ./setup.sh --yes      skip the confirmation (for a re-run you already trust)
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0
ASSUME_YES=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY=1 ;;
        --yes|-y)  ASSUME_YES=1 ;;
        *) echo "unknown argument: $arg" >&2; exit 2 ;;
    esac
done

if [[ $EUID -eq 0 ]]; then
    echo "don't run this as root — it deploys into \$HOME and calls sudo where it needs to" >&2
    exit 1
fi

# Plain while-read instead of mapfile: this also has to run under the ancient bash
# on bekh's mac when he sanity-checks it before shipping to the mini.
STEPS=()
while IFS= read -r s; do STEPS+=("$s"); done \
    < <(find "$REPO/scripts" -maxdepth 1 -name '[0-9][0-9]-*.sh' | sort)

if [[ ${#STEPS[@]} -eq 0 ]]; then
    echo "no scripts found in $REPO/scripts" >&2
    exit 1
fi

echo "hyprland — plan"
echo
for s in "${STEPS[@]}"; do
    # The second comment line of each script is its one-line summary.
    desc="$(sed -n '3p' "$s" | sed -e 's/^# *//' -e 's/^[^—]*— //' | cut -c1-58)"
    printf '  %-22s %s\n' "$(basename "$s")" "$desc"
done
echo
echo "  repo:   $REPO"
echo "  target: ${XDG_CONFIG_HOME:-$HOME/.config}"
echo
echo "  not touched: navidrome, slskd, jellyfin-server, the linux-t2 kernel stack,"
echo "               or anything else already running. No pacman -Syu."
echo

if [[ $DRY -eq 1 ]]; then
    echo "(dry run — nothing executed)"
    exit 0
fi

if [[ $ASSUME_YES -eq 0 ]]; then
    read -r -p "run these? [y/N] " answer
    [[ "$answer" == [yY]* ]] || { echo "aborted"; exit 0; }
fi

for s in "${STEPS[@]}"; do
    echo
    echo "───── $(basename "$s") ─────"
    bash "$s"
done

echo
echo "───── done ─────"
