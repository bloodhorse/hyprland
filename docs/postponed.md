# Postponed

Dashboard and panel work is **postponed entirely**. No dashboard content lives in this repo —
only these pointers, so nothing has to be re-discovered later.

A status bar is a separate matter: **never**. bekh has never used one. Permanently out of
scope, not postponed.

Everything below stays in the `ags-dashboard` repo.

| artifact | what it is |
|---|---|
| `eww-dashboard-rxyhn/dashboard/` | the only dashboard that ever actually rendered — rxyhn's TokyoNight eww config adapted, plus bekh's own scripts (`eww-tweak`, `metrics`, `oscillo`, `pin-ws.sh`, `ccu`) and a 19-file eww docs set. If revived: geometry is hardcoded for betrayer's panel, and `metrics` shells out to `nvidia-smi`, which is dead on the mini's Intel GPU. |
| `notes/dashboard-journey.md` | the postmortem — why AGS died (Astal swallows `layer`), why Fabric died (CircularProgressBar allocation bug), and the meta-lesson: find the reference dotfiles repo instead of rebuilding from a screenshot. |
| `notes/eww-layout-lessons.md`, `dashboard/docs/gtk-quirks.md`, `docs/shell-safety.md` | accumulated eww/GTK pain notes. |
| `wtfutil/README.md` | a terminal-panel plan. Work-wired — slave lag, Jenkins, YouTrack — and the mini is a no-work machine. If a panel ever happens it gets re-planned around personal signals. Also embeds real infra hostnames; do not copy it here. |
| `term-widget/` | terminal-native widget sketch, same shelf as wtfutil. |

Two traps in that repo, flagged so nobody consolidates blind: `docs/hyprland.md` teaches the
inline `layerrule` syntax that does not work (see [lessons.md](lessons.md)), and
`notes/project_dashboard_stack.md` + `notes/MEMORY.md` still declare Fabric the winner.
