# keyd: layers и модификаторы — как оно реально работает

Конспект после дебага бага V1.2 (физ-F при Super открывал терминал вместо fullscreen).

## Базовая модель

- **main** — нижний слой стека. По умолчанию каждая клавиша забиндена сама на себя (или на твой ремап типа colemak-DH).
- Активные слои образуют **стек occluding keymaps**, консультируются в порядке активации.
- `[control]`, `[meta]`, `[alt]`, `[shift]`, `[altgr]` — встроенные виртуальные слои. Авто-активируются при удержании соответствующего модификатора. Не требуют явного `leftmeta = layer(meta)`.

## Синтаксис `[name:M]`

Двоеточие+модификаторы = "эмулировать эти модификаторы при отсутствии явного маппинга".

Классический пример из man:
```
capslock = layer(capslock)
[capslock:C]
j = down
```
Caps работает как Ctrl, но `capslock+j` даёт `down` (БЕЗ Ctrl — потому что bindings не затрагиваются модификатором слоя).

**Ключевая цитата из man(1) keyd:**
> bindings are not affected by the modifiers of the layer in which they are defined

То есть `:M` влияет ТОЛЬКО на unmapped клавиши. Mapped — эмитятся как написано, без меты.

## Fallthrough unmapped (наш баг)

Если клавиша НЕ замаплена в активном слое — падает вниз по стеку до main.

В нашем случае:
1. Hold Super → активируется виртуальный `[meta]` слой
2. Press физ-F → в `[meta]` нет записи `f`
3. Fallthrough в main → `f = t` срабатывает → эмитится `t`
4. Параллельно `:M` default эмитит Meta
5. Hyprland видит `Super+T` → биндинг на терминал

**:M НЕ защищает raw scancode от main-ремапа.** Cmd+C/V/X/Z/A работают, потому что мы их явно прописали в `[meta]`. Cmd+(физ-F) ломается, потому что fallthrough.

## Подтверждения из upstream

- [#705](https://github.com/rvaiya/keyd/issues/705) (open) — фича-реквест на `default = action` для unmapped в layer. Сейчас этого нет, только `:модификаторы`.
- [#728](https://github.com/rvaiya/keyd/issues/728) (closed) — `:M` эмитит leftmeta сразу при входе в layer (а не при нажатии), ломает XFCE launcher. Дизайн модификаторных слоёв — известная мутная зона.
- [#752](https://github.com/rvaiya/keyd/issues/752) (open) — буквально наш кейс: "intended way to fallthrough to QWERTY on held Meta" с colemak в main. Без резолюции.
- [#765](https://github.com/rvaiya/keyd/issues/765) (open) — Shift+nav-layer arrow даёт капс вместо Shift+arrow. Соседняя проблема взаимодействия модификаторов и слоёв.

**Вывод: это не баг keyd, а архитектурное ограничение.** Виртуальные слои не дают qwerty-fallthrough из коробки когда main = colemak.

## Единственное надёжное решение

Явно прописать ВСЕ буквы в `[meta]` (и `[control]`, `[alt]` если нужно) как `<scancode> = M-<qwerty-letter>`. Это перекрывает main-ремап через явный маппинг.

```
[meta]
q = M-q
w = M-w
e = M-e
... (все 26 букв)
```

Применено в V1.3.

## Тупики которые НЕ работают (проверено)

- `[meta:M]` сам по себе — не помогает, fallthrough всё равно жрёт main-ремап.
- `default_layout = ...` в `[global]` — `could not find default layout`, такой переменной нет.
- `swap(main)` для en/ru — `the main layer cannot be toggled`, запрещено.
- `leftmeta = layer(bare_meta)` или `overload(bare_meta, leftmeta)` — варнинг "use layer(meta) instead", и не решает суть.
