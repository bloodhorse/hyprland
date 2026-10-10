# mac hotkeys — the SPEC side

**What this is.** The ground-truth inventory of bekh's macOS window-management and keyboard
bindings, extracted from the live configs and their working notes. This is the **SPEC**: the
Hyprland config on the mini maps *to* this document, not the other way round. Where a binding
exists here, the port has to reproduce the **behavior**, not just the keycap.

**Prior art, not spec.** The betrayer-era Hyprland binds (documented in
`docs/keyd-era-v1/DEPLOYMENT.md` and `hypr-keys/README.md`) are a previous machine's config. Useful
as reference for Hyprland syntax and for the keyd/kanata layer — but they are *not* the target.
Anything in them that contradicts this file loses.

**Sources** (every binding below is traceable to one of these; paths are absolute):

| # | Path | What it is |
|---|------|-----------|
| S1 | `/Users/bekh/wrk/techshit/hyprland/aerospace/aerospace.toml` | live AeroSpace config, mirrored from `~/.aerospace.toml` by a pre-commit hook |
| S2 | `/Users/bekh/wrk/techshit/hyprland/aerospace/CLAUDE.md` | current live-state orientation doc (2026-07-30) — agrees with S1 |
| S3 | `/Users/bekh/wrk/techshit/hyprland/aerospace/README.md` | the deep conspectus (the *why*) — **written for the three-monitor era, key table is stale**, see §7 |
| S4 | `/Users/bekh/wrk/techshit/hyprland/mac-bin/` | the `~/bin` scripts the bindings call |
| S5 | `/Users/bekh/wrk/techshit/hyprland/aerospace/bin/notch-kill.sh` | the frida window-expander (lives at `~/.local/bin/notch-kill.sh`) |
| S6 | `/Users/bekh/wrk/techshit/hyprland/aerospace/killem.md` | write-up behind `alt-shift-q` |
| S7 | `/Users/bekh/wrk/techshit/hyprland/aerospace/cross-monitor-fullscreen-clamp-bug.md` | why cross-monitor moves need a refit |
| S8 | `/Users/bekh/wrk/techshit/hyprland/aerospace/ghostty-redraw-bug.md` | Ghostty blank-window bug |
| S9 | `/Users/bekh/wrk/techshit/hyprland/aerospace/aerospace.3mon.toml` | frozen three-monitor config (historical) |
| S10 | `/Users/bekh/wrk/techshit/hyprland/hypr-keys/inventory/karabiner-rules.md` | distilled Karabiner inventory (keyboard-level, non-WM). Source is in Russian; translated below |

**Counts.** 65 active bindings in AeroSpace `[mode.main.binding]` + 28 in `[mode.c.binding]` = 93
window-manager binds, plus 2 commented-out express lanes. On top of that: 11 Karabiner rules (9
enabled, 2 disabled) and 1 Karabiner rule documented only in S2. 21 named workspaces.

---

## 0. How to read the key names

- **`alt` = the Option key.** Every WM binding except three uses `alt` as the sole modifier;
  `cmd-g`, `cmd-m` and `ctrl-left/right` are the exceptions. Which Hyprland modifier `alt` becomes
  on the mini is an open question — see §8.
- **AeroSpace binds the *emitted keysym*, not the physical position.** bekh types **Gallium Colstag
  natively** (S2), always on, chords included, and thinks in letters. So `alt-s` means "the key that
  types `s` wherever gallium put it". There are no positional bindings left in the live config — the
  last one (mode c's old roguelike snap grid) went out with the Raycast deeplinks on 2026-07-30.
  The one place the *shape* still matters is the mode-c snap grid, where the letters happen to form
  a spatial map on the colstag (see §5.6).
- **Workspace names ≠ their keys.** Workspaces called `minus` and `equal` live on the **bracket**
  keys (`alt-[` / `alt-]`); the names stuck from before gallium moved `-`/`=` off those positions.
  Likewise workspace `d2` is on `alt-=`, workspace `d` is on `alt-c`.
- **F13–F17, not F1–F5** — macOS eats F1–F12 as the media row before AeroSpace ever sees them.
  F13–F20 arrive untouched (same reason `alt-f19` works). The Lily58's ZMK layer emits real F13–F17.

---

## 1. Workspace switching — `[mode.main.binding]` (S1 lines 58–90)

Switch to a workspace. AeroSpace is used **purely as virtual desktops** — every window is
`layout floating`, no tiling, no native macOS fullscreen (S1, S2, S3 §intro).

| Binding | Action | Implementation | Notes / intent |
|---|---|---|---|
| `alt-1` … `alt-9` | switch to ws `1`…`9` | `workspace N` | primary block; ws 1–6 pinned to DELL, 7–9 to Built-in |
| `alt-0` | switch to ws `10` | `workspace 10` | the zero KEY's workspace is *named* `10`, not `0` — a real bug once put augury on a ghost ws `0` no key reached (fixed 2026-07-30, S1 line 288) |
| `alt-[` | switch to ws `minus` | `workspace minus` | name is legacy; key is the bracket |
| `alt-]` | switch to ws `equal` | `workspace equal` | same |
| `alt-=` | switch to ws `d2` | `workspace d2` | parked legacy from the three-monitor DELL-chatter plan; kept bound so nothing dangles |
| `alt-c` | switch to ws `d` | `workspace d` | same — parked, unused |
| `alt-f19` | switch to ws `section` | `workspace section` | `section` is also the startup workspace (`after-startup-command`) |
| `alt-f13` … `alt-f17` | switch to ws `f13`…`f17` | `workspace fNN` | five extra workspaces on the primary, pressed from the ZMK layer |
| `alt-esc` | switch to ws `esc` | `workspace esc` | purpose-agnostic scratch workspace on the primary. Option+Esc is not a macOS system shortcut, so it gets through |
| `ctrl-right` | next workspace | `workspace next` | the only non-alt WM nav binding |
| `ctrl-left` | previous workspace | `workspace prev` | |

**Workspace → monitor pinning** (S1 lines 24–54, S2). Deterministic, survives display rearrange:

| Monitor | Workspaces |
|---|---|
| **DELL P2416D** — primary, landscape, macOS main, at global origin `(0,0)` | `1 2 3 4 5 6` · `f13 f14 f15 f16 f17` · `esc` · `d d2` (parked) |
| **Built-in** — secondary, physically to the LEFT (negative frame origin) | `7 8 9 10` · `section` · `minus` · `equal` |

---

## 2. Haul window → workspace (+ follow) — S1 lines 97–121

Every one of these calls `~/bin/move-to-workspace <ws>` (S4). Never a bare AeroSpace directive —
see §5.2 and §5.3 for why.

| Binding | Action | Implementation | Notes / intent |
|---|---|---|---|
| `alt-shift-1` … `alt-shift-9` | move focused window → ws `1`…`9`, follow it | `exec-and-forget ~/bin/move-to-workspace N` | atomic move+follow, conditional refit |
| `alt-shift-0` | → ws `10` | `move-to-workspace 10` | |
| `alt-shift-[` / `alt-shift-]` | → ws `minus` / `equal` | `move-to-workspace minus` / `equal` | |
| `alt-shift-f19` | → ws `section` | `move-to-workspace section` | |
| `alt-shift-f13` … `alt-shift-f17` | → ws `f13`…`f17` | `move-to-workspace fNN` | |
| `alt-shift-c` | → ws `d` | `move-to-workspace d` | parked pair with `alt-c` |
| `alt-shift-=` | → ws `d2` | `move-to-workspace d2` | parked pair with `alt-=` |
| `alt-shift-esc` | → ws `esc` | `move-to-workspace esc` | |
| `alt-shift-r` | reload AeroSpace config | `reload-config` | mostly vestigial since `auto-reload-config = true` (2026-07-30); the auto-reload **lags a beat** behind the file write, so a brand-new binding can look dead on the first try |

---

## 3. Monitors, geometry, blackout

| Binding | Action | Implementation | Notes / intent |
|---|---|---|---|
| `alt-o` | toss focused window to the *other* monitor | `~/bin/move-to-other-monitor` (S4) | reads the current monitor and picks the explicit other of DELL↔Built-in. **Why a script:** AeroSpace's `move-node-to-monitor A B` name list is a **fallback list, not a cycle** — it always hits the first existing pattern, so from that monitor it's a silent no-op (verified 0.20.3, S3 §5) |
| `alt-shift-s` | swap the contents of the two visible workspaces (DELL ↔ Built-in) | `~/bin/swap-monitors` (S4) | assumes **one normal window per screen**; explicitly **not** for Ghostty (native tab monorail tears at the seam). Swaps workspace *content* rather than moving across monitors, because workspaces are hard-pinned to monitors. Ends by focusing the DELL workspace |
| `alt-v` | fullscreen toggle | `fullscreen` (native AeroSpace directive) | AeroSpace's own fullscreen — **not** macOS native fullscreen, which is contraband (§6) |
| `alt-shift-v` | expand window under the notch / behind the menu bar | `~/.local/bin/notch-kill.sh` (S5) | macOS-only concept; see §6 |
| `alt-b` | blackout / restore the **Built-in** display | `~/bin/display-dim-toggle --nameLike=Built-in` | mnemonic = **initials**: B = Built-in |
| `alt-l` | blackout / restore the **DELL** | `~/bin/display-dim-toggle --nameLike=DELL` | L = de**L**L |
| `alt-d` | — | commented out, parked | was the 3rd screen's slot in the three-monitor era. If a third screen returns, S2 says decide the mnemonic system fresh (positional vs initials) |

---

## 4. Express lanes, session utilities, the modal-layer gate — S1 lines 128–174

| Binding | Action | Implementation | Notes / intent |
|---|---|---|---|
| `alt-n` | focus **Arc** | `~/bin/focus-app company.thebrowser.Browser` | |
| `alt-z` | focus **Zed** | `~/bin/focus-app dev.zed.Zed` | |
| `alt-w` | focus **kitty** | `~/bin/focus-app net.kovidgoyal.kitty` | kitty holds the live ssh / pt-osc sessions — it is deliberately never swept by `killem` |
| `alt-s` | focus **Safari** | `~/bin/focus-app com.apple.Safari` | |
| `alt-m` | focus **Mattermost** | `~/bin/focus-app Mattermost.Desktop` | |
| `alt-g` | focus **Ghostty** | `~/bin/focus-app com.mitchellh.ghostty` | |
| `alt-r` | focus **Kagi** | *commented out* in S1 | free slot |
| `alt-t` | focus **Ghostty-Fun** (2nd personal Ghostty, own bundle id) | *commented out* in S1 | free slot; `alt-f` would have suited "fun" but was taken |
| `alt-e` | open a **new Finder window here** | `~/bin/finder-here` | never raises existing windows — see §5.5 |
| `alt-shift-e` | close **all** Finder windows | `osascript -e 'tell application "Finder" to close every window'` | Finder ignores Cmd-Q; this is the manual sweep |
| `alt-shift-w` | play the frontmost browser tab's video in mpv, spanned across every monitor | `~/bin/span-play` | see §6 |
| `alt-q` | toggle the **Jot** quick-note window | `~/bin/jot-toggle.sh` | clicks Jot's menu-bar icon via System Events. `q` = **Q**uick note; moved off `alt-j` on 2026-07-15 because gallium puts `j` on the right hand and express lanes live on the left |
| `alt-shift-q` | **killem** — end-of-day sweep: quit every app on the kill-list, report survivors | `~/bin/killem` | see §5.8 |
| `cmd-g` | enter **mode c** (the command layer) | `mode c` | deliberate chord, see §5.6 |
| `cmd-m` | **nothing — deliberately eaten** | `exec-and-forget true` | the *minimize ban*: a minimized window is unreachable for both cmd-tab and AeroSpace's AX raise, and was the prime suspect behind "hotkey does nothing but the window exists". Banned at the root. The yellow button still minimizes — that's a deliberate click |
| `keypadClear` | enter mode c | `mode c` | dead legacy: Karabiner used to emit this from a Left-Command tap-alone. Karabiner no longer emits it; the binding is kept as a harmless no-op |

---

## 5. Patterns that are more than single binds

### 5.1 Express lanes — address apps by identity, not by place

**The problem** (S3 §1, and it is a real diagnosis, not a preference). Navigating to apps by
*workspace number* fails under cognitive load: the number is recallable in ~1s, but the hands start
blind-cycling `alt-1`, `alt-2`, … *before* recall finishes, and the search degrades. It's a
**timing/impulse** problem — the action fires before the recall lands — not a memory gap. "Just
pause and think" doesn't work because the pause breaks hyperfocus.

**The fix.** One dedicated key per app that focuses *that app's window wherever it is*, replacing
recall-and-scan with a single muscle-memory chord. Numbers stay sacred for the spatial model;
express lanes are the express ramps onto it.

**The mechanism — `~/bin/focus-app <bundle-id>` (S4), raise-or-cycle, monitor-aware.** This is the
behavior the Hyprland port must reproduce:

1. **No windows of that app open** → launch it, poll for up to ~6s (40 × 0.15s — enough for a cold
   Electron start), focus the first window that appears. (Finder is special-cased: an explicit
   `make new Finder window`.)
2. **Not currently focused on this app** → focus the instance **under the mouse**. This is the point:
   the *first* press never teleports you across the monitor seam to a window you weren't looking at.
3. **Already focused on this app** → **cycle** to the next of the app's windows, ordered
   *mouse-monitor windows first, then everything else*. So repeated presses walk every window,
   including the ones on the other monitor.

The focus must go **through the window manager**, not through the OS's own "activate this app" path.
On macOS, native activation (what Raycast's "Hotkey to App" does) makes the app frontmost in the
OS's mind but never tells AeroSpace to bring its workspace forward → desync: "menu says Arc, screen
shows kitty". `aerospace focus --window-id` performs the workspace switch itself. **Hyprland
equivalent: the focus call must also switch the workspace** — a raise that leaves you on the wrong
workspace is the exact failure this design exists to kill.

*Proposed but not built (S2):* teach `focus-app` to clear a minimized flag before the raise, and to
log one line per invocation (app asked, windows seen with ws + minimized flags, window chosen,
outcome) — to turn "~30% of the time, no pattern" into data.

### 5.2 Teleport is atomic

`move-to-workspace` does the move **and** the follow in ONE call
(`aerospace move-node-to-workspace --focus-follows-window`). The old two-call form
(`move-node-to-workspace` then `workspace`) had a gap in which the window was already off the current
workspace but the view hadn't switched yet → an **emptied-workspace blink on every single teleport**,
even within one monitor. Atomic kills it. (S3 §5, S4.)

**Port note:** Hyprland's `movetoworkspace` already moves+follows in one dispatch, so this pattern
comes free — but it is the *behavior* to verify, not just the dispatcher name.

### 5.3 Refit after a cross-monitor move — a macOS crutch with a portable *intent*

AeroSpace does not recompute floating geometry on a move, so a window hauled to a different-sized
monitor lands mis-sized. Both `move-to-workspace` and `move-to-other-monitor` therefore refit — but
**only if the move actually crossed a monitor boundary** (`before != after`).

The conditional is load-bearing, and for a reason that *does* generalize: within one monitor a bare
"fullscreen" refit is **harmful** — it drags a window that was expanded under the notch back down
below it. So: *never re-fit a window that didn't change screens.*

There's a second, subtler bit (S4 `move-to-workspace` lines 21–43): on a cross-monitor move the
fullscreen flag survives the move and makes the subsequent fullscreen a no-op, leaving the window
stuck at the *old* monitor's geometry. So the flag is cleared **while the window is still on the old
monitor**, and only when the move is really going to cross.

The refit itself runs `notch-kill.sh` on every cross-monitor branch. That part is a pure macOS
crutch (§6) — Hyprland recomputes geometry itself. What transfers is the **shape**: cross-monitor
move → conditional refit → same-monitor move → touch nothing.

### 5.4 Multi-monitor model

- **Each workspace lives on exactly one monitor**, fixed by `[workspace-to-monitor-force-assignment]`
  (S1 lines 24–54). Without the pinning AeroSpace dumps every unpinned workspace onto whatever the OS
  currently calls the main display and leaves the others as stubs — which actually happened on a
  display rearrange. Pinning makes it deterministic and rearrange-proof. **If a monitor is absent**
  (laptop solo) its workspaces fall back to main and stay reachable.
- **Match monitors by NAME, never by numeric id.** AeroSpace's `monitor-id` is left-to-right position
  and reshuffles on rearrange (currently `1 = Built-in, 2 = DELL`, i.e. the reverse of the physical
  order). Every script that touches a monitor resolves the name to an id fresh, every time.
- **Focus ≠ cursor.** Window-manager "focus" is the keyboard target and the anchor for the next
  command; the pointer is separate. They are coupled by
  `on-focus-changed = ['move-mouse monitor-lazy-center']` — on any focus change jump the pointer to
  the focused monitor's centre, *lazily* (only if it isn't already on that monitor).
- **KNOWN BUG in exactly that hook (S2, "Drag-across-monitors rodeo").** Dragging a window across the
  monitor seam *with the mouse* bucks and snaps back: mid-drag the window crosses the border → focus
  changes → the WM teleports the cursor (which is holding the window) to the monitor centre.
  Root-caused, upstream issue [#634](https://github.com/nikitabobko/AeroSpace/issues/634), surgery
  designed but not applied — drop the global hook, re-add the mouse-warp as a second command in each
  workspace-switch binding and at the tail of `focus-app` / `move-to-workspace`.
  **Port straight to the fixed design: warp the cursor on deliberate switches, never on every focus
  change.**

### 5.5 Per-app fixes

**Finder — ghost windows (S3 §4).** Finder keeps *closed* windows alive as objects in both its
scripting model and AeroSpace's tracking, while the accessibility API says there's one real window.
There is no "is-real" flag, so addressing Finder by window id is a minefield. **Decision: don't hunt
the live window.** `alt-e` opens a *new* Finder window on the current workspace and focuses it by
diffing the tracked window-id list before/after — the id that appears is the new window.
`alt-shift-e` is the manual sweep. Two macOS gotchas were fixed along the way (tabbing mode forcing
every new window into a tab; AppleScript ignoring the "New windows show" pref, so the script reads
that pref itself). The window is sized to **72% of the focused monitor, centred** — and pointedly
*not* measured from Finder's own desktop bounds, which is the union of all monitors glued together
(that produced a window spanning both displays).

**Ghostty — native-tab monorail (S3 §6).** On macOS a Ghostty tab is a separate NSWindow that macOS
glues into a tab group, and **macOS forbids a tab group from spanning two monitors**. So the WM sees
N windows for N tabs, and any cross-monitor move of a Ghostty window snaps at the seam. No config
escape. This is why `swap-monitors` explicitly excludes Ghostty. **kitty has no such problem** —
own-drawn tabs = one GPU window = one window to the WM. *This constraint is macOS-specific and
should evaporate on Hyprland; the port should re-test whether Ghostty can be treated as a normal
window again.*

**Ghostty — redraw / blank-window bug (S8), UNRESOLVED, parked.** A summoned Ghostty window sometimes
comes up on a blank workspace: focused correctly, just not drawn. A size kick (the fullscreen toggle)
surfaces it. Not reproducible on demand. Suspected residual WM state corruption.

**Apps that steal focus.** A misbehaving app can grab focus back and break a workspace switch
(caught live: Orion). Symptom: the WM reports the target focused while the visible-workspace list
still shows the old workspace on that monitor.

### 5.6 mode c — the ONE modal layer

Entered by the **deliberate chord `cmd-g`**. Inside `[mode.c.binding]`, **every bound key fires its
action and auto-returns to main**. (S1 lines 197–259, S2.)

**Why a chord and not a modifier tap.** It used to be a single tap of Left Command (Karabiner
`to_if_alone` → `keypadClear`). Dropped: a bare-modifier tap-alone **misfires constantly** — tried
and reverted three times, same fate as single/double-tap-alt. A chord is intentional and can't
misfire (tmux-prefix logic). The cost is that `cmd-g` (Find Next) is now eaten globally.

**THE GOTCHA that killed the previous layer, and the single most important porting lesson here:**
a key that is *unbound* inside mode c falls through to the app as a typed letter **and the mode stays
on**, eating the following keystrokes as grid commands. It reads as "the hotkey is broken" when it
was simply never bound. Lost? Press `q`. **The Hyprland submap must therefore bind — or explicitly
swallow — everything, and always have an escape.**

| Key | Action | Implementation |
|---|---|---|
| `q` | exit the layer | `mode main` |
| `esc` | haul window → ws `esc`, then exit | `~/bin/move-to-workspace esc` + `mode main` |
| `1`…`9`, `0` | haul window → ws `1`…`10` | `~/bin/move-to-workspace N` + `mode main` |
| `[` / `]` | haul → ws `minus` / `equal` | `move-to-workspace minus` / `equal` |
| `d` | haul → ws `d` | `move-to-workspace d` |
| `=` | haul → ws `d2` | `move-to-workspace d2` |
| `s` | haul → ws `section` | `move-to-workspace section` |
| `h` | snap window to **left half** | `~/bin/snap left-half` |
| `e` | snap to **right half** | `~/bin/snap right-half` |
| `o` | snap to **top-left quarter** | `~/bin/snap top-left` |
| `a` | snap to **bottom-right quarter** | `~/bin/snap bottom-right` |
| `←` / `→` / `↑` / `↓` | snap to left / right / top / bottom **half** | `~/bin/snap <half>` |
| `g` | focus **kitty** | `~/bin/focus-app net.kovidgoyal.kitty` |
| `w` | **voice input** (superwhisper) | `open -g superwhisper://record` |
| `v` | expand under the notch | `~/.local/bin/notch-kill.sh` |

Free in mode c: `f` `p` `j` `y` `k` `m`.

**The snap grid mnemonic** (S1 lines 234–243). The four letters sit on the colstag like this, and
the *shape* is the whole mnemonic:

```
        o          ← middle finger, top row  = TOP-LEFT quarter
   h    a    e     ← home row: index = LEFT half · middle = BOTTOM-RIGHT quarter · ring = RIGHT half
```

Arrows do the four halves as well — bound not because they're elegant but because *the hands reach
for them*, and an unbound key in mode c is the worst failure mode there is (see the gotcha above).

**`~/bin/snap` (S4)** — puts the **WM-focused** window into a fractional region of *its own* monitor.
Region table (all fractions of the monitor's visible area, origin top-left): `left-half` `right-half`
`top-half` `bottom-half` · `top-left` `top-right` `bottom-left` `bottom-right` · `left-third`
`center-third` `right-third` `left-two-thirds` `right-two-thirds` · `center` (0.1667/0.1667/0.6666/
0.6666) · `almost-max` (0.03 inset) · `max`. Also accepts an ad-hoc `snap <fx> <fy> <fw> <fh>`, a
`--gap N` inset, `--monitor NAME` override, `--frame` (use the full screen frame instead of the
visible frame), `--dry`, and `--list`. Adding a region is one line.

Two design points worth carrying over:
- It replaced Raycast deeplinks (deleted 2026-07-30) because those cost a ~300ms LaunchServices
  roundtrip **and acted on whatever the OS considered FRONTMOST — which is not always the window the
  WM has focused.** That gap is the same ghost-focus disease behind the dead-hotkey mysteries.
  **Rule: always act on the WM's focused window, never on the OS's idea of "frontmost".**
- It clears the WM's own fullscreen flag first, otherwise the window stays *marked* fullscreen while
  sitting in a half-frame and the next fullscreen toggle restores a stale frame instead of expanding.

### 5.7 App default homes — `[[on-window-detected]]` (S1 lines 261–299)

An experiment re-introduced 2026-07-21 (it had been removed in June, see §7 disagreement #4):

| App | Lands on |
|---|---|
| kitty | ws `esc` |
| Ghostty | ws `1` |
| Safari | ws `2` |
| Zed | ws `3` |
| Arc | ws `5` |
| Mattermost | ws `6` |
| augury | ws `10` |
| *everything else* | wherever focus currently is |

Two mechanical traps baked into that config, both worth knowing because they're a class of bug, not
a one-off: **only the first matching rule runs**, so every per-app rule must repeat `layout floating`
itself or the window lands tiled; and the catch-all rule needs an explicit `if = 'true'` — a bare
`run` is a hard config error, and a config error **silently falls back to the default config, which
is tiling**, i.e. the exact thing the whole setup forbids.

The foundation rule: **everything floating.** AeroSpace is virtual desktops only. That's a settled
decision (S2, "Settled — don't relitigate"): tiling would fight the three other frame-owners
(the frida expander, mpv's own geometry, hand placement), and two owners of one frame is perpetual
war. **This is the single biggest open question for the port — see §8.**

### 5.8 `killem` — the end-of-day sweep (`alt-shift-q`, S6)

Quits every app on a **kill-list**, reports what went and what survived, and flashes
`killem — N quit` centre-screen. It deliberately **asks nothing** — the whole point is to stop
deciding and let the desk go quiet. `--dry` previews, `--list` prints the list, `--running` prints
bundle ids of everything open so the list can grow by copy-paste. Flight recorder at
`/tmp/killem.log`.

Four load-bearing decisions, each of which was wrong the first time:

1. **The app list is enumerated from the OS's "regular" (Dock-visible) apps** — not from the WM's
   window list (which spared a windowless Arc, exactly the clutter meant to go, and can't see a
   natively-fullscreened window), and not from System Events' "not background only" (which returns
   `loginwindow`, `Dock`, `SystemUIServer` next to Safari — sweeping that takes the session down).
2. **Kill-list, not keep-list.** With a keep-list, any hole in the enumeration destroys something you
   cared about. Inverted, the failure mode inverts with it: a miss means "that app is still open",
   which you see instantly and fix with one line. Bounded blast radius beats zero maintenance.
3. **Graceful terminate, never SIGKILL.** A hard kill skips saving; a hotkey that can kill a terminal
   mid-migration is not a hotkey worth having.
4. **Address apps by bundle id, not process name** — process names lie (augury's binary is literally
   named `app`).

Current list (15 ids): Arc, Safari, FaceTime, Zed, Mattermost, Ghostty, Ghostty-Fun, Kagi, Codex,
Claude for Desktop, Telegram, Signal, Spotify, Mimestream, Zoom. **Deliberately absent:** kitty (it
hosts live ssh / pt-osc sessions), augury, the WM itself, Finder, and every menu-bar agent.

It also **polls rather than sleeps** while waiting for apps to die — calling something a survivor
while it's still on its way out sends you hunting for a dialog that isn't there. And the report
names *where* survivors live (workspace + monitor), because an app holding unsaved work will sit
with a modal dialog on a workspace you cannot see.

### 5.9 Blackout — one key per monitor

`~/bin/display-dim-toggle <selector>` drops a monitor's brightness to 0 to "turn it off", and
restores the remembered level on the next press. Three things in it are design, not accident:

- **One hard key per screen, never cursor-tracking.** The action must be unambiguous.
- **The brightness decides the branch, never a state file.** Rescue a blacked screen with the media
  keys and a file-based toggle goes stale — the next press "restores" an already-lit screen (a dead
  press) and only the one after blacks out. *The screen is the truth; the file is just a memo of
  where to return to.* Fallback level 0.7 if the memo is missing or junk.
- **Resolve the selector to a single display identity first, then act only on that identity.** A
  name-ish selector could match a group and black out both screens.

It also retries flaky reads (a garbage read used to silently eat the keypress — the "double-press"
symptom) and keeps a per-invocation flight recorder.

**Mac-specific rot that does *not* transfer:** the whole DDC-vs-software-brightness saga (the old
DELL drops its DisplayPort link on a DDC brightness write, blanking both externals for seconds).
On Linux the equivalent lever is `ddcutil` / a compositor gamma control — same *behavior*, entirely
different machinery.

### 5.10 The unbound-but-real scripts in `~/bin`

Not keybound, but part of the transfer surface (S4): **`dirindex`** (indexes dirs+files under `~`
with `fd` into `~/.cache/yazi/{dirs,files}.idx` so yazi's fzf jump is instant; atomic temp-then-move
swap so a reader never sees a half-written index; run from launchd, hence the explicit PATH),
**`iphone-keepalive.sh`** (pings the iPhone's Tailscale IP every 20s to keep the iOS network stack
warm for Zepp's fetch), and **`snap-helper.swift`** (the compiled fast path for `snap` — ~85ms vs
the ~250ms scripting fallback). **`keytap-server`** is a compiled Swift binary committed with no
source and no reference anywhere in the sources — unknown purpose, flagged in §8.

---

## 6. mac-only — does NOT transfer

| Thing | Binding | Why it's meaningless on Linux |
|---|---|---|
| **notch-kill** | `alt-shift-v`, mode c `v` | It exists to defeat `NSWindow -constrainFrameRect:toScreen:`, the AppKit clamp that forbids a window occupying the display notch / menu-bar strip, patched at runtime with frida. No notch, no menu-bar reservation, no clamp on Wayland |
| **the cross-monitor refit crutch** | inside `move-to-workspace`, `move-to-other-monitor`, `swap-monitors` | Same clamp, second face: macOS lazily re-associates a moved window with its new screen and clamps *growth* to the old screen's size (ask 1920×1080, get 720×1280). Hyprland recomputes geometry on move. Keep the conditional-refit *shape* (§5.3), drop the machinery |
| **the minimize ban** | `cmd-m` eaten | Bans macOS minimize-to-Dock, which makes a window unreachable to both cmd-tab and AX raise. Hyprland has no minimize by default |
| **cmd-tab kill** | Karabiner rule (S2) | The macOS app switcher activates the *app* and raises its most-recently-used window across all workspaces — visually nothing happens ~30% of the time. Rooted in an upstream AeroSpace decision to cut native-focus sync to off-screen windows. No such component on Hyprland |
| **`keypadClear` → mode c** | S1 line 170 | Dead artifact of a retired Karabiner tap-alone rule |
| **Jot toggle** | `alt-q` | Clicks a macOS menu-bar icon of a mac-only note app. The *slot* should survive (one key for a scratch-note overlay); the app and the mechanism don't |
| **Finder ghost-window handling** | `alt-e`, `alt-shift-e` | The whole `finder-here` design exists because Finder keeps closed windows as live objects and ignores its own "new window shows" pref. A Linux file manager just opens a window |
| **`AppleWindowTabbingMode`, Ghostty native tab groups** | — | macOS glues tabs into NSWindow tab groups that can't span monitors (§5.5) |
| **"Displays have separate Spaces" = OFF** | system setting | A macOS Spaces setting. Relitigated and settled; no Wayland analogue |
| **native macOS fullscreen is contraband** | policy | A natively-fullscreened window lives in its own macOS Space that the WM cannot see or switch to — the hotkey feels dead. Hyprland's fullscreen has no such hidden dimension |
| **superwhisper** | mode c `w` | mac-only dictation app driven by a URL scheme. The *slot* transfers; needs a Linux STT binding |
| **Caramba (Right Option → double Shift)** | Karabiner rule #4 | mac-only utility; also already disabled |
| **Colemak Mod-DH per-device remap** | Karabiner rule #3 | Already lives in the Lily58's ZMK firmware + XKB on the Linux side |
| **BetterDisplay / DDC blackout machinery** | behind `alt-b` / `alt-l` | The *action* transfers; `betterdisplaycli`, the UUID resolution and the DELL DDC link-drop bug do not |
| **`span-play`'s implementation** | `alt-shift-w` | The mpv-`--geometry`-in-device-pixels trick + re-asserting geometry over the IPC socket after `file-loaded` exists solely to dodge AppKit's single-display fullscreen and its AX resize clamp. Whether the *goal* (one video across all monitors) is even reachable on Hyprland is an open question — §8 |

---

## 7. Where the conspectus and the live config DISAGREE

Reported rather than resolved, as required. In every case **S1 (the live `.toml`) and S2 (the
current-state doc) agree with each other**, and **S3 (the README conspectus) is the stale one** —
it is explicitly marked as still written for the three-monitor era. Trust S3 for *mechanisms*, never
for key assignments.

| # | S3 (conspectus) says | S1 / S2 (live) say | Verdict |
|---|---|---|---|
| 1 | Express lanes: `alt-a`=Arc, `alt-v`=Zed, `alt-k`=kitty, `alt-w`=Ghostty, `alt-t`=Ghostty-Fun, `alt-r`=Kagi (§2 table) | `alt-n`=Arc, `alt-z`=Zed, `alt-w`=kitty, `alt-g`=Ghostty; `alt-t`/`alt-r` **commented out**; `alt-v` is now the **fullscreen toggle** | S3 stale. Use the live keys. Note `alt-v` and `alt-w` mean *different things* in the two documents — the highest-risk trap in this whole port |
| 2 | `alt-shift-v` = span-play (§5c) | `alt-shift-w` = span-play; `alt-shift-v` = notch-kill | S3 stale |
| 3 | Blackout: `alt-b`=BenQ, `alt-g`=Built-in, `alt-d`=DELL (§5) | `alt-b`=Built-in, `alt-l`=DELL, `alt-d` parked | S3 stale — the mnemonic was flipped from *positional* to *initials* on 2026-07-30 when the desk dropped to two screens |
| 4 | "App→workspace auto-assignment was **removed** (2026-06-25) … the only `on-window-detected` rule left is the global catch-all" (§3) | Seven per-app default-home rules are live (re-added 2026-07-21) plus the catch-all | S3 stale; S2 documents the re-add. **Both facts matter for the port**: the homes exist *now*, but they were removed once for a real reason (an app you launched got yanked to another screen), so treat them as an experiment, not a settled requirement |
| 5 | `alt-o` moves between **BenQ** ↔ Built-in, DELL→BenQ (§5) | the live script is a pure **DELL ↔ Built-in** toggle | S3 stale (BenQ sold 2026-07-27) |
| 6 | S7/S8 refer to `alt-f` (fullscreen) and `alt-shift-f` (notch-kill) | those are `alt-v` / `alt-shift-v` now | historical names in bug docs; the *mechanisms* they describe are current |
| 7 | S10 (Karabiner inventory) lists 11 rules, none of them a cmd-tab disable | S2 states cmd-tab is disabled by a Karabiner rule ("Disable Cmd+Tab (app switcher)" → `vk_none`, `optional: any`), added 2026-07-30 | **The Karabiner inventory predates the rule and is incomplete.** Re-dump Karabiner before finalising the keyboard-level port |

---

## 8. Keyboard-level bindings (non-WM) — from S10

S10 is written in Russian; translated here. Verdicts are S10's own, kept as-is.

| # | Rule | What it does | S10's transfer verdict |
|---|---|---|---|
| 1 | Caps Lock → English (ABC) | pressing Caps sets the system layout to EN | **high** priority — pressed constantly. Linux: `hyprctl switchxkblayout` |
| 2 | Fn (Globe) → Russian | Globe sets the layout to RU | **high**. Deterministic per-key layout selection, *not* a toggle |
| 3 | Colemak Mod-DH (Lily58 only) | per-device remap for the Lily58 | **do not transfer** — already in ZMK |
| 4 | Right Option → double Shift | Caramba trigger | **DISABLED in Karabiner** — do not transfer |
| 5 | F13→`,` F14→`.` F15→`?` (RU) | punctuation on the Russian layout | **high** — Russian typing breaks without it |
| 6 | same, EN layout | punctuation on English | **high** |
| 7 | shift+7 → `?` (EN) | shift+7 gives `?` instead of `&` | medium — habit |
| 8 | Space = Command (hold) / Space (tap) | space-cadet | **DISABLED in Karabiner** — bekh tried it and turned it off; separate task if he ever wants it back |
| 9 | Shift+Alt+C → screenshot to clipboard | cmd wrapper around screenshot | medium — direct Hyprland equivalent: `hyprshot -m region --clipboard-only` |
| 10 | Ctrl+S → TTS stop | stop silero | **high** — daily |
| 11 | Ctrl+T → TTS speak selection (XTTS) | voice the selection | **high** |
| — | **Disable Cmd+Tab** | kills the macOS app switcher entirely (see §6) | mac-only, nothing to port |

S10's own transfer order: (1) Caps/Globe layout switching, (2) the two TTS binds, (3) F13–F15
punctuation, (4) screenshot.

**App-level, outside both WM and Karabiner:** Ghostty scroll binds mirror kitty's —
`cmd+shift+k` / `cmd+shift+j` = scroll ±3 lines (S3 §6). Deliberately moved *off* `ctrl+j/k`
because those clobber readline (`ctrl+k` = kill-line, `ctrl+j` = LF); `cmd` is never sent to the
shell, so it's safe. **On Linux there is no cmd — pick a modifier the shell never sees.**

---

## 9. Open porting questions

1. **`alt` → which Hyprland modifier?** 65 of 93 WM binds hang off `alt` alone. Hyprland convention
   is `SUPER`, and the betrayer-era config (prior art) used `SUPER` throughout. Straight `ALT` keeps
   the muscle memory intact but collides with app-level Alt shortcuts far more on Linux than on
   macOS. Needs bekh's call, and it is a one-way door for muscle memory.
2. **Keysym or keycode?** AeroSpace binds the *emitted letter*, and bekh types Gallium Colstag
   natively — so `alt-s` follows the letter wherever the layout puts it. Hyprland's `bind = ALT, S`
   binds the keysym (layout-dependent, RU layout breaks it), while `bind = ALT, code:39` binds the
   physical position (layout-independent, but then the letter mnemonic dies on a non-QWERTY layout).
   **These are opposite behaviors and the mac side deliberately chose "letter".** Also unresolved:
   S2 says Gallium Colstag; the betrayer-era `hypr-keys/README.md` says XKB `colemak_dh_ortho`.
   Which layout the mini actually runs decides this question.
3. **Tiling or floating?** The mac setup is `layout floating` *everywhere* — settled, with reasons
   (three competing frame-owners). Hyprland is a tiling compositor by nature; the betrayer-era
   config used real tiling with MNEI focus/move/resize navigation. Reproducing the mac behavior means
   `windowrule = float, .*` plus a snap grid — which throws away most of what Hyprland is for. This
   is the biggest architectural fork in the port and it is **not** a keybinding question.
4. **Do the MNEI navigation binds come back?** The mac config has **no** directional focus/move/
   resize binds at all — no equivalent of `Super+H/J/K/L`. That's a direct consequence of floating +
   snap grid. If the mini tiles, an entire family of binds has to be *invented*, not ported, and the
   betrayer config is the only prior art.
5. **21 workspaces, or fewer?** The mac uses named workspaces (`minus`, `equal`, `section`, `esc`,
   `d`, `d2`, `f13`–`f17`). Hyprland supports named workspaces, but `f13`–`f17` + `f19` depend on
   the Lily58 ZMK layer emitting real F13–F19 — which it does on Linux too. `d` / `d2` are parked
   legacy and probably shouldn't be ported at all. `esc` (scratch) and `section` (startup) earn
   their keep.
6. **Monitor names.** Every script matches monitors by *name substring* (`DELL`, `Built-in`).
   The mini's monitor identities and count are unknown here — the whole pinning table and both
   blackout binds need re-derived names before anything works.
7. **What replaces `focus-app`'s raise-or-cycle?** Hyprland has `focuswindow` with class regexes,
   but the mac behavior is specific: land on the instance *under the mouse* on the first press, then
   cycle mouse-monitor-first. That's a script, not a dispatcher — needs writing against
   `hyprctl clients -j` + the cursor position.
8. **Can a window span monitors on Hyprland at all?** `span-play` (`alt-shift-w`) puts one video
   across every display. Hyprland windows belong to exactly one monitor, so the *goal* may be
   unreachable and the bind may need to become something else (e.g. mirrored output, or mpv on the
   biggest screen). Needs a real test before deciding.
9. **Is the "mouse warp on focus change" behavior wanted at all?** The mac has it globally and it
   *causes* the drag-across-monitors bug (§5.4). Hyprland has its own cursor-warp settings; the
   right move is probably to port the **fixed** design (warp on deliberate switches only), not the
   current one.
10. **Does the `killem` sweep transfer, and against what?** The concept is solid and the four design
    decisions (§5.8) are portable, but the enumeration source has to be replaced. Also worth asking
    whether the kill-list is even the same list of apps on the mini.
11. **`keytap-server`** — a compiled Swift binary in `~/bin` with no source committed, no reference
    in any config or doc, and no keybinding pointing at it. Purpose unknown. Ask bekh whether it's
    live before deciding to port or drop it.
12. **Per-app default homes: keep or drop?** They were removed once for a good reason and re-added
    as an experiment three weeks later (§7 #4). The port shouldn't inherit an unsettled experiment
    without asking.
