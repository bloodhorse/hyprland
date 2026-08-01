# Lessons

Pain already paid for. Read this before debugging something that "should obviously work" —
several of these cost hours the first time.

Each entry: the fact, why it bites, where it came from.

> **Version note.** The syntax lessons below were paid for on Hyprland **0.54.3**. miniarch
> runs **0.55.4**, and 0.56.0 is out upstream with no breaking changes from 0.55. Nothing is
> known to have regressed — but re-verify the layerrule and windowrule block-form rules on
> first boot rather than assuming. Separately, 0.56.1 adds a deprecation notice for `.conf`
> configs: upstream is heading for Lua. Not urgent, but the format has a sunset.

---

## Hyprland config syntax

### layerrule must be block form, and `name` must come first (0.54+)

Inline `layerrule = blur, <namespace>` — with or without the comma — **silently does
nothing** on 0.54.x. It does not blur and it does not obviously fail; the parser rejects the
line with `special category's first value must be the key. Key for <layerrule> is <name>`
and moves on. Only this works:

```ini
layerrule {
    name = blur-fuzzel
    match:namespace = launcher
    blur = true
}
```

`ignorealpha` is not accepted as a standalone keyword (`invalid field ignorealpha`).

**Why it matters:** five hours went into "blur is broken on this compositor" when blur was
fine — the rule was never being applied. Advice found online (and from other models) still
teaches the comma form.

**Second half of the same trap:** layer rules are evaluated when the layer is **created**.
`hyprctl reload` is not enough — you must restart the application that owns the layer surface
before you can tell whether the rule works.

Source: `ags-dashboard/notes/project_hyprland_layerrule_054.md`

### windowrule: same rule, `name` first

```
special category's first value must be the key. Key for <windowrule> is <name>
```

Named-block window rules need `name = …` as the literal first field. Anything else in front
of it and the whole block is discarded.

Source: `ags-dashboard/notes/hyprland-rulebook.md`

### `stayfocused` does not exist

`config option <windowrule:stayfocused> does not exist`. It is not a typo for anything — the
field simply is not there. Focus behaviour is controlled by `no_focus` and `focusonactivate`.

Source: `ags-dashboard/notes/hyprland-rulebook.md`

### v0.53 broke windowrules; v0.45 broke shadows

Two breaking changes worth knowing before copying any config off the internet:

- **v0.53** — `windowrulev2` with the old `class:^(kitty)$` matcher syntax is deprecated and
  removed. The current form is `windowrule = float on, match:class kitty`, or the named block
  form above.
- **v0.45** — `decoration:shadow` became a nested section. The old flat keys (`drop_shadow`,
  `shadow_range`, …) are dead.

Practically: any config snippet older than mid-2025 needs a syntax audit before it goes in,
and "it doesn't work" usually means "it didn't parse".

Source: `~/Desktop/_tomove/hypr.md`

---

## Performance

### `misc:vfr = true` — do not turn it off

Variable frame rate. Without it the compositor renders every frame even when nothing on
screen changed. On the mini's Intel UHD 630 that is a permanent tax for zero benefit.

### `animation = borderangle, …, loop` is a permanent GPU burn

The `loop` style forces a redraw every frame, forever, including on a completely idle
desktop. On a laptop it eats the battery; on the mini it just heats an iGPU that also has a
music stack to serve.

`configs/hypr/hyprland.conf` currently has this animation enabled. It is bekh's taste and has
not been touched — but if the mini ever runs hot or the animations stutter, this is the first
line to comment out.

The other expensive knobs, in order: `blur` with `passes > 2`, shadows, fractional scaling.
A reasonable balance on weak GPUs is blur `size=3, passes=2`, shadow `render_power=3`,
animations at 4–7 deciseconds, integer scale.

Source: `~/Desktop/_tomove/hypr.md`

---

## Wayland application plumbing

### Electron apps need `ELECTRON_OZONE_PLATFORM_HINT=auto`

```ini
env = ELECTRON_OZONE_PLATFORM_HINT,auto
```

Without it, older Electron builds fall back to XWayland — blurry text on a scaled display,
broken clipboard, broken screen sharing. Electron 38.2+ detects Wayland on its own, but most
installed apps are behind that.

### `dbus-update-activation-environment` in exec-once, or portals stay dead

```ini
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
```

xdg-desktop-portal is started by D-Bus, which does not inherit the compositor's environment.
Without this line the portal comes up without `WAYLAND_DISPLAY` and screen sharing plus the
file picker are quietly broken.

### Exactly one portal backend

`xdg-desktop-portal-hyprland` and `xdg-desktop-portal-wlr` must **not** both be installed —
they race to claim the same interfaces and the loser's failures look like random breakage.
Install `-hyprland` plus `-gtk` (for the file chooser) and nothing else. Check with
`systemctl --user status xdg-desktop-portal-hyprland`.

### A missing notification daemon hangs applications

Some apps (Discord is the known case) block waiting for a notification service that never
answers. This is why `swaync` is in `packages/core.lst` even though nothing in the configs
obviously requires it.

Source for all four: `~/Desktop/_tomove/hypr.md`

---

## macOS font feel

The single biggest visual difference is **hinting**. macOS does not hint — glyphs stay
slightly soft but keep their designed proportions. Linux hints by default, snapping glyphs to
the pixel grid: sharper, and immediately not-mac.

`~/.config/fontconfig/fonts.conf`:

```xml
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hinting" mode="assign"><bool>false</bool></edit>
    <edit name="rgba" mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
  </match>

  <!-- bitmap fonts ruin the effect -->
  <selectfont>
    <rejectfont>
      <pattern><patelt name="scalable"><bool>false</bool></patelt></pattern>
    </rejectfont>
  </selectfont>

  <alias>
    <family>sans-serif</family>
    <prefer><family>Inter</family></prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer><family>JetBrains Mono</family></prefer>
  </alias>

  <!-- web pages asking for the mac system font get Inter -->
  <match target="pattern">
    <test qual="any" name="family"><string>-apple-system</string></test>
    <edit name="family" mode="prepend" binding="same"><string>Inter</string></edit>
  </match>
  <match target="pattern">
    <test qual="any" name="family"><string>Helvetica Neue</string></test>
    <edit name="family" mode="prepend" binding="same"><string>Inter</string></edit>
  </match>
</fontconfig>
```

Plus, in `hyprland.conf`:

```ini
env = FREETYPE_PROPERTIES,truetype:interpreter-version=40
```

Interpreter v40 renders smoother and less grid-fitted. Run `fc-cache -fv` after any change.

**Inter** is the legal SF Pro stand-in — visually very close, open source. Apple's SF Pro is a
free download but its licence restricts use to developing for Apple platforms.

Note: this file does not exist in `configs/` yet. Writing it is a TODO.

Source: `~/Desktop/_tomove/hypr.md`

---

## keyd

### `[meta:M]` does not protect keys from the main-layer remap

The one architectural limit that shapes the entire keyboard config.

keyd's `[name:M]` suffix means "emulate this modifier for keys that have **no explicit
mapping** in the layer". Straight from `man keyd`: *bindings are not affected by the
modifiers of the layer in which they are defined.* So an unmapped key in `[meta]` falls
through the layer stack down to `[main]` — and `[main]` is where Colemak-DH lives. It gets
remapped on the way past. Hold Super, press physical F, and Hyprland receives Super+T.

There is no `default = action` for layers (upstream issue #705, still open; #728, #752, #765
are the neighbouring symptoms). **This is not a bug — it is how modifier layers are
designed.**

The only reliable fix is brute force: write out all 26 letters explicitly in `[meta]` as
`<scancode> = M-<qwerty-letter>`. An explicit mapping overrides the main-layer remap. That is
what keyd V1.3 does, and why its config looks so verbose.

Dead ends already tested — do not retry: `[meta:M]` alone, `default_layout` in `[global]`
(no such variable), `swap(main)` (the main layer cannot be toggled),
`leftmeta = layer(bare_meta)` (warns, solves nothing).

Full write-up: `hypr-keys/keyd/HOW-IT-WORKS.md`. Deployment history and the surviving
Hyprland bind table: `hypr-keys/keyd/DEPLOYMENT.md`.

### Emergency stop

If keyd wedges the keyboard: **Backspace + Escape + Enter together** — keyd terminates
itself. Worth memorising before the first deploy, not after.

---

## Working on the mini remotely

### `hyprctl` over ssh needs the instance signature

`hyprctl` finds its socket through `HYPRLAND_INSTANCE_SIGNATURE`, which an ssh session does
not have. Read it from the live lock file:

```bash
SIG=$(ls /run/user/1000/hypr/ | head -1)
HYPRLAND_INSTANCE_SIGNATURE=$SIG hyprctl reload
```

### `pkill -f <pattern>` kills the ssh session

The remote shell running the command has `<pattern>` in its own argv, so pkill signals itself
and ssh dies with 255. Kill by numeric PID or PGID instead.

Source: `ags-dashboard/docs/remote-workflow.md`
