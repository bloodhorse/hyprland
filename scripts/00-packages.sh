#!/usr/bin/env bash
#
# 00-packages.sh — installs the repo packages from packages/*.lst with `--needed`, so
# re-running it is a no-op on an already-provisioned box. [AUR]-tagged lines go through
# yay if it is present.
#
# WILL NOT:
#   * run `pacman -Syu` — no full system upgrade from here. miniarch is a T2 Mac on the
#     linux-t2 kernel (apple-bcm-firmware, t2fanrd, apple-t2-audio-config); a blind
#     upgrade is how a desktop project becomes a machine that will not boot.
#   * install or replace any kernel, bootloader, or firmware package.
#   * remove anything, ever. Losing packages (waybar, wofi, rofi, hyprlauncher, foot,
#     weston) are listed in the README as cleanup candidates, not removed by a script.
#   * bootstrap an AUR helper.
#   * touch navidrome, slskd, jellyfin-server, or any systemd unit.
#
# Safety net worth knowing about: root is btrfs with snapper + snap-pac, so every
# pacman transaction gets an automatic pre/post snapshot. Rollback exists.
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Anything matching this never gets installed by this script, no matter what a .lst
# says. Belt and braces: the lists are hand-written and hands slip.
FORBIDDEN='^(linux|linux-t2|linux-lts|linux-zen|linux-firmware|linux-headers.*|.*-headers|grub|systemd-boot.*|refind.*|apple-bcm-firmware|t2fanrd|apple-t2-audio-config|mkinitcpio.*)$'

repo_pkgs=()
aur_pkgs=()
skipped=()

for lst in "$REPO"/packages/*.lst; do
    [[ -f "$lst" ]] || continue
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        pkg="$(sed -e 's/[[:space:]]*#.*//' -e 's/[[:space:]]*$//' <<< "$line")"
        [[ -n "$pkg" ]] || continue
        if [[ "$pkg" =~ $FORBIDDEN ]]; then
            echo "!! refusing kernel/boot/firmware package from $(basename "$lst"): $pkg" >&2
            continue
        fi
        if grep -q '\[AUR\]' <<< "$line"; then
            aur_pkgs+=("$pkg")
        else
            repo_pkgs+=("$pkg")
        fi
    done < <(grep -v '^[[:space:]]*#' "$lst" | grep -v '^[[:space:]]*$')
done

# Pre-flight: a name that is not in any repo would abort the whole transaction and
# leave the run half-done. Report it and carry on with the rest instead.
wanted=()
for p in "${repo_pkgs[@]:-}"; do
    [[ -n "$p" ]] || continue
    if pacman -Si "$p" >/dev/null 2>&1; then
        wanted+=("$p")
    else
        skipped+=("$p")
    fi
done

if [[ ${#wanted[@]} -gt 0 ]]; then
    echo "==> pacman -S --needed  (${#wanted[@]} packages)"
    # No --noconfirm on purpose: this box serves music. You look at the transaction
    # before it runs.
    sudo pacman -S --needed "${wanted[@]}"
else
    echo "==> nothing to install from the repos"
fi

if [[ ${#skipped[@]} -gt 0 ]]; then
    echo
    echo "!! not found in any repo — check the name or move it to an [AUR] line:"
    printf '     %s\n' "${skipped[@]}"
fi

if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
    echo
    if command -v yay >/dev/null 2>&1; then
        echo "==> yay -S --needed  (${#aur_pkgs[@]} AUR packages)"
        yay -S --needed "${aur_pkgs[@]}"
    else
        echo "==> no AUR helper found. Install these yourself:"
        printf '     %s\n' "${aur_pkgs[@]}"
    fi
fi

# The fontconfig recipe in docs/lessons.md is inert until fc-cache has seen the files.
if command -v fc-cache >/dev/null 2>&1; then
    echo "==> fc-cache -f"
    fc-cache -f >/dev/null
fi

echo "==> 00-packages: done"
