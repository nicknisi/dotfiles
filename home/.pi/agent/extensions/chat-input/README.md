# chat-input

Replaces pi's input editor with a configurable boxed input. All native editor
features — cursor movement, history, autocomplete, paste — work normally inside
the box. Evolved from the earlier single-file `box-editor.ts`.

## Features

- **Rounded or square box**: `╭╮│╰╯` (default, preserves the original look) or `┌┐│└┘`
- **Configurable prefix glyph** on the first body line (default `❯`)
- **Theme-aware borders**: any theme colour token or hex value
- **Boxed / unboxed**: full box with sides, or top/bottom horizontal rules only
- **Menu outside box**: slash menu (`/`) renders below the box, indented
- **Scroll indicators**: `↑ N more` / `↓ N more` embedded in the borders when content scrolls
- **Responsive**: degrades gracefully on narrow terminals
- **Focus indicator**: border switches colour when the tmux pane holding this
  session has terminal focus (requires tmux `focus-events on`)

## Configuration

User config lives in `~/.pi/agent/configs/chat-input.json`. Create it to override
defaults (config is read once at extension load — restart pi to apply):

```json
{
  "boxedView": true,
  "boxPadX": 1,
  "menuGap": 0,
  "extraMenuIndent": 1,
  "borderColor": "border",
  "prefix": "❯",
  "prefixColor": "accent",
  "corners": "rounded",
  "focusIndicator": true,
  "focusedBorderColor": "accent"
}
```

| Option               | Type                    | Default     | Description                                                                                                              |
| -------------------- | ----------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------ |
| `boxedView`          | `boolean`               | `true`      | `true` = full box with side borders. `false` = top/bottom horizontal rules only.                                         |
| `boxPadX`            | `number`                | `1`         | Horizontal padding inside the box (and around the prefix).                                                               |
| `menuGap`            | `number`                | `0`         | Blank lines between the bottom border and the slash-menu.                                                                |
| `extraMenuIndent`    | `number`                | `1`         | Extra indent (spaces) for slash-menu lines.                                                                              |
| `borderColor`        | `string`                | `"border"`  | Theme colour token **or** hex colour (`"#ff6600"`) for the box border.                                                   |
| `prefix`             | `string`                | `"❯"`       | Prefix glyph shown on the first body line.                                                                               |
| `prefixColor`        | `string`                | `"accent"`  | Theme colour token **or** hex colour for the prefix.                                                                     |
| `corners`            | `"rounded" \| "square"` | `"rounded"` | `rounded` = `╭╮│╰╯`, `square` = `┌┐│└┘`.                                                                                 |
| `focusIndicator`     | `boolean`               | `true`      | Track terminal focus (DECSET 1004) and restyle the border when this pane is focused. Requires `focus-events on` in tmux. |
| `focusedBorderColor` | `string`                | `"accent"`  | Border colour while the pane is focused; `borderColor` is used when unfocused.                                           |

### Colour tokens

Any valid theme colour token works. See your active theme in `~/.pi/agent/themes/`
or via `/settings → Theme` for available tokens (`border`, `accent`, `text`,
`muted`, `success`, `error`, `customMessageLabel`, …).
