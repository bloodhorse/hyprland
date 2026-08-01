#!/usr/bin/env bash
#
# 99-verify.sh — read-only self-check. Prints a verdict per item so you never have to
# judge raw output: ✓ means present, ✗ MISMATCH means it is not.
#
# WILL NOT: install, remove, enable, disable, or write anything at all. It never calls
# hyprctl either — miniarch is headless during prep, there is no Wayland session to
# talk to, so this has to be answerable over a bare ssh connection. Safe to run at any
# time, including while the music stack is serving.
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

ok()   { printf '  ✓ %s\n' "$1"; }
bad()  { printf '  ✗ MISMATCH: %s\n' "$1"; fail=$((fail + 1)); }
note() { printf '    %s\n' "$1"; }

# ── packages ───────────────────────────────────────────────────────────
# [AUR] entries are checked too: once yay has installed one, pacman -Q knows it.
for lst in "$REPO"/packages/*.lst; do
    [[ -f "$lst" ]] || continue
    echo "==> $(basename "$lst")"
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] || continue
        if pacman -Q "$pkg" >/dev/null 2>&1; then ok "$pkg"; else bad "$pkg not installed"; fi
    done < <(grep -v '^[[:space:]]*#' "$lst" | sed -e 's/#.*//' -e 's/[[:space:]]*$//' | grep -v '^$')
done

# ── binaries ───────────────────────────────────────────────────────────
# Package name != binary name often enough that presence in pacman is not proof the
# thing you bound a key to actually exists on PATH.
echo "==> binaries on PATH"
for bin in Hyprland hyprctl kitty fuzzel keyd wl-copy wl-paste cliphist wtype \
           wpctl playerctl hyprsunset grim slurp swaync nvim jq; do
    if command -v "$bin" >/dev/null 2>&1; then ok "$bin"; else bad "$bin not on PATH"; fi
done

echo "==> binaries referenced by configs but not in packages/"
# bekh's own scripts. Absence is a TODO, not a failure — reported without incrementing
# the failure count.
for bin in awww awww-daemon toggle-darkmode hyprshutdown; do
    if command -v "$bin" >/dev/null 2>&1; then ok "$bin"; else note "absent: $bin"; fi
done

# ── fonts ──────────────────────────────────────────────────────────────
echo "==> fonts"
if command -v fc-list >/dev/null 2>&1; then
    fc-list | grep -qi 'JetBrainsMono Nerd' && ok "JetBrainsMono Nerd Font" || bad "JetBrainsMono Nerd Font"
    fc-list | grep -qi ':Inter'             && ok "Inter"                    || bad "Inter"
else
    bad "fc-list missing (fontconfig)"
fi

# ── cleanup candidates ─────────────────────────────────────────────────
# Installed, but lost the decision. Informational only — nothing here removes them,
# and none of them break anything by sitting there. Remove by hand when you're sure.
echo "==> cleanup candidates (installed but superseded — NOT removed by this repo)"
for pkg in waybar wofi rofi hyprlauncher foot weston; do
    pacman -Q "$pkg" >/dev/null 2>&1 && note "present: $pkg" || true
done

# ── hyprland version ───────────────────────────────────────────────────
# Read from pacman, not hyprctl — there is no running instance on a headless box.
# The 0.53 windowrule break and the 0.45 shadow break are both below this line; the
# syntax notes in docs/lessons.md were written against 0.54 and want a re-check on 0.55.
echo "==> hyprland version"
if hv="$(pacman -Q hyprland 2>/dev/null)"; then
    note "$hv"
    case "$hv" in
        *\ 0.5[45]*) : ;;
        *) note "outside the 0.54–0.55 range docs/lessons.md was written against" ;;
    esac
else
    bad "hyprland not installed"
fi

# ── the stack that must not have been harmed ───────────────────────────
# Read-only sanity check. This repo never touches these; if one is down, that is
# news worth having before you blame something else.
echo "==> service stack (untouched by this repo — checked, never modified)"
for unit in navidrome slskd jellyfin-server; do
    if systemctl list-unit-files --type=service 2>/dev/null | grep -q "^${unit}\.service"; then
        state="$(systemctl is-active "${unit}.service" 2>/dev/null || true)"
        [[ "$state" == "active" ]] && ok "$unit: active" || note "$unit: $state"
    else
        note "$unit: no such unit here"
    fi
done

echo
if [[ $fail -eq 0 ]]; then
    echo "VERDICT: MATCH — everything the configs need is present"
else
    echo "VERDICT: $fail MISMATCH(es) above"
    exit 1
fi
