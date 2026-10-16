#!/bin/bash
# tt — the master theme switch on the mini, the mac's toggle-theme.sh ported:
# it SETS a mode absolutely and pushes it into everything; kt (kitty) and ct
# (claude code) stay the local toggles and get pulled back in line by the next
# tt. The shared .zshrc aliases tt to this name on both boxes.
#
# What a mode is here:
#   the portal's color-scheme  zen, gtk4/libadwaita and kitty-aware apps follow it live
#   gtk theme and icons        adw-gtk3(-dark), Colloid-Teal(-Dark), in gsettings and settings.ini
#   the house layers           dark: the house gtk.css, qt palette and kdeglobals (written by
#                              skin); light: none of them, the toolkits' own light look
#   kitty, claude code         kt, ct
# gtk3, qt and KDE apps read their files at start: a window already open keeps its
# colours until it is reopened. The quickshell boxes and the borders do not change.
#
# Usage: tt / tt light / tt dark
cfg=~/tower/temper/hyprland/configs
state=~/.local/state/house
mkdir -p "$state"

case "${1:-toggle}" in
  light|dark) next=$1 ;;
  toggle)
    [ "$(gsettings get org.gnome.desktop.interface color-scheme)" = "'prefer-dark'" ] \
      && next=light || next=dark ;;
  *) echo "usage: tt [light|dark]" >&2; exit 1 ;;
esac

if [ "$next" = dark ]; then
  gsettings set org.gnome.desktop.interface color-scheme prefer-dark
  gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
  gsettings set org.gnome.desktop.interface icon-theme Colloid-Teal-Dark
  ln -sf "$cfg/gtk/gtk.css" ~/.config/gtk-3.0/gtk.css
  ln -sf "$cfg/gtk/gtk4.css" ~/.config/gtk-4.0/gtk.css
  ln -sf "$cfg/gtk/settings.ini" ~/.config/gtk-3.0/settings.ini
  ln -sf "$cfg/gtk/settings.ini" ~/.config/gtk-4.0/settings.ini
  ln -sf "$cfg/qt/qt5ct.conf" ~/.config/qt5ct/qt5ct.conf
  ln -sf "$cfg/qt/qt6ct.conf" ~/.config/qt6ct/qt6ct.conf
  [ -f "$state/kdeglobals-dark" ] && mv "$state/kdeglobals-dark" ~/.config/kdeglobals
else
  gsettings set org.gnome.desktop.interface color-scheme prefer-light
  gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3
  gsettings set org.gnome.desktop.interface icon-theme Colloid-Teal
  ln -sf "$cfg/gtk/light.css" ~/.config/gtk-3.0/gtk.css
  ln -sf "$cfg/gtk/light.css" ~/.config/gtk-4.0/gtk.css
  ln -sf "$cfg/gtk/settings-light.ini" ~/.config/gtk-3.0/settings.ini
  ln -sf "$cfg/gtk/settings-light.ini" ~/.config/gtk-4.0/settings.ini
  ln -sf "$cfg/qt/qt5ct-light.conf" ~/.config/qt5ct/qt5ct.conf
  ln -sf "$cfg/qt/qt6ct-light.conf" ~/.config/qt6ct/qt6ct.conf
  [ -f ~/.config/kdeglobals ] && mv ~/.config/kdeglobals "$state/kdeglobals-dark"
fi
echo "system theme: $next"

"$cfg/bin/kt" "$next"
"$cfg/bin/ct" "$next"
