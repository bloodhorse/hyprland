# keyd deployment на betrayer

Боевая раскатка keyd как замены carabiner-стиля для colemak-DH-ortho на Hyprland.

**Текущий статус:** V1.3 в проде, работает.

---

## V1.3 (2026-04-24) — текущая

### Главное отличие от V1.2

В `[meta]` явно прописаны ВСЕ буквы как `M-<qwerty-letter>`. Без этого fallthrough unmapped клавиш падает в main и получает colemak-ремап (физ-F → t → Hyprland видит Super+T вместо Super+F).

Теория и обоснование — [HOW-IT-WORKS.md](HOW-IT-WORKS.md).

### Конфиг
Файл: `/etc/keyd/default.conf` (= [keyd/default.conf](default.conf) в репо).

Структура:
- `[ids] 1d50:615e` — только Lily58
- `[main]` — colemak-DH-ortho + Caps→Esc
- `[meta]` — Cmd+C/V/X/Z/A → Ctrl+C/V/X/Z/A; все остальные буквы явно как M-qwerty
- `[control]`, `[alt]` — пустые, identity через :C/:A default

### Hyprland-биндинги (мак-семантика)

В `~/.config/hypr/hyprland.conf`:

| Клавиша (физ qwerty) | Действие |
|----------------------|----------|
| `Super + F` | терминал |
| `Super + E` | fullscreen |
| `Super + Q` | killactive (Cmd+Q) |
| `Super + W` | sendshortcut Ctrl+W activewindow (Cmd+W → close tab) |
| `Super + R` | лаунчер (fuzzel) |
| `Super + Shift + V` | togglefloating (Super+V занят на paste) |

Удалено:
- `Super + T → togglesplit`
- `Super + Space → лаунчер` (оставили только Super+R)

Бэкапы: `~/.config/hypr/hyprland.conf.bak.*` (keyd-rollout, macshortcuts, tfswap)

### xkb на бетрейере

Колмак убран из xkb, делает только keyd:
```
kb_layout = us,ru
kb_variant = ,
kb_options = grp:alt_space_toggle
```

### Что работает

- Колмак-DH-ortho печать
- Caps → Esc
- Cmd+C/V/X/Z/A → copy/paste/cut/undo/select-all
- Cmd+(физ-letter) даёт Super+(qwerty-letter) для Hyprland-биндов — мак-семантика
- Hyprland Super+1..0, стрелки и т.д. — без изменений

### Что НЕ работает / открытые вопросы

**A. Русский язык сломан под keyd.** keyd ремапит на ru тоже, физ-V даёт scancode-D → xkb-ru → 'в' вместо ожидаемой 'м'. Решение V2: либо переписать ru-раскладку в keyd как отдельный layer, либо watcher hyprctl-events → keyd reload со swap файлов конфига. Пока живём с этим.

**B. Ctrl+C/V на ru вообще.** Даже если решить A — на ru xkb даёт keysym 'с' (cyrillic) вместо 'c' (latin). Многие приложения не реагируют. Karabiner на маке решает это переключением input source при Cmd-hold. На линуксе — переписать всю раскладку в keyd, при Cmd/Ctrl-hold atomically переключаться на en-layer.

---

## История версий

### V1.2 (2026-04-24, утро) — провалилась
Использовал только `:M` default modifier в `[meta]` без явных per-key мапов. Думал что unmapped клавиши получат meta+identity. Реальность: fallthrough идёт в main с применением colemak-ремапа. Cmd+(физ-F) открывал терминал вместо fullscreen. Подробности в HOW-IT-WORKS.md.

### V1.3 (2026-04-24, день) — текущая
Явные `M-<qwerty>` для всех букв в `[meta]`. Перекрывает main-ремап.

---

## Откат

```bash
ssh -i $KEY bekh@100.100.166.114 '
  sudo systemctl stop keyd && sudo systemctl disable keyd
  cp ~/.config/hypr/hyprland.conf.bak.keyd-rollout-* ~/.config/hypr/hyprland.conf
  SIG=$(ls /run/user/1000/hypr/ | head -1)
  HYPRLAND_INSTANCE_SIGNATURE=$SIG hyprctl reload
'
```

Опц. вернуть kanata: `paru -S kanata-bin && sudo systemctl enable --now kanata`.

**Аварийный stop keyd с клавы:** Backspace+Escape+Enter одновременно — keyd terminates сам.

---

## Установка с нуля

1. `paru -S keyd && sudo systemctl enable --now keyd`
2. Удалить kanata если есть: `paru -Rns kanata-bin` (конфликт за `/dev/input/event*`)
3. `sudo cp keyd/default.conf /etc/keyd/default.conf && sudo keyd reload`
4. Убрать colemak из `~/.config/hypr/hyprland.conf` (`kb_variant = ,` без colemak_dh_ortho)
5. Применить мак-биндинги (см. таблицу выше) в `hyprland.conf`
6. `hyprctl reload`

---

## История проб (тупики)

1. **`default_layout = colemak_main`** в `[global]` — `could not find default layout`. Видимо переменной нет.
2. **`swap(main)` для en/ru** — `the main layer cannot be toggled`. Запрещено.
3. **`leftmeta = layer(bare_meta)`** или `overload(bare_meta, leftmeta)` — warning "use layer(meta) instead". У keyd есть встроенные виртуальные `[control]/[meta]/[alt]/[altgr]`, не нужно переопределять модификатор-клавиши.
4. **`[meta:M]` без явных маппингов** (V1.2) — не помогло, fallthrough в main применяет colemak-ремап. Это и есть баг V1.2.
