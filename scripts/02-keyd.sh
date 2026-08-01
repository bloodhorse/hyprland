#!/usr/bin/env bash
#
# 02-keyd.sh — STUB. The keyd config is not in this repo yet; it still lives in
# hypr-keys. This script only tells you where it is and what has to happen.
#
# WILL NOT: write /etc/keyd/anything, enable or start keyd.service, remove kanata,
# or change the keyboard in any way. Deliberately — a bad keyd config on a headless
# box you reach over ssh is survivable, but on a box you are standing at with one
# keyboard it is a bad afternoon. Deploy it by hand, with the emergency stop known.
#
set -euo pipefail

cat <<'EOF'
==> 02-keyd: nothing installed (stub)

The V1.3 config that actually shipped lives in the hypr-keys repo:

    hypr-keys/keyd/default.conf        the config
    hypr-keys/keyd/DEPLOYMENT.md       install steps, rollback, open problems
    hypr-keys/keyd/HOW-IT-WORKS.md     why [meta] spells out all 26 letters

To deploy by hand:

    paru -S keyd
    sudo cp <hypr-keys>/keyd/default.conf /etc/keyd/default.conf
    sudo systemctl enable --now keyd
    sudo keyd reload

Before you do:

  * THE LAYOUT CHANGED. That default.conf holds Colemak-DH in [main]; bekh types
    Gallium (Colstag) now. It is a TEMPLATE to rewrite, not a drop-in. Settled
    (bekh, 2026-08-01): on the mac Gallium lives in Karabiner, so the Lily58
    firmware sends QWERTY-position codes — on the mini keyd takes Karabiner's
    role and [main] must hold the Gallium letter table.
    See docs/keyboard-pipeline.md.
  * kanata must NOT be installed — it fights keyd over /dev/input/event*.
  * The letter layout must be OUT of xkb. configs/hypr/hyprland.conf is already set
    to kb_layout = us,ru / kb_variant = , for exactly this reason.
  * [ids] 1d50:615e scopes keyd to the Lily58 only. The mini has no built-in
    keyboard, so that is correct as written.
  * EMERGENCY STOP: Backspace + Escape + Enter together kills keyd. Memorise it now.
  * Russian input under keyd is still broken. See docs/keyboard-pipeline.md.

TODO: move the keyd config into this repo once it has been re-verified on miniarch,
then make this script actually install it.
EOF
