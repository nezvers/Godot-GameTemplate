# Bundled fonts

| Font | Source | Licence |
|---|---|---|
| `raylib_default_10px.tres` | raylib's built-in default font (`defaultFontData[]` / `charsWidth[]` in `rtext.c`, © 2013-2026 Ramon Santamaria) | zlib/libpng - redistributable, see https://github.com/raysan5/raylib/blob/master/LICENSE |
| `SourceSans3-Regular.ttf` | `raylib_base_template/resources/fonts/font.ttf` (Source Sans 3 Regular, © 2021 Adobe) | SIL Open Font License 1.1 - redistributable, see https://scripts.sil.org/OFL |

`raylib_default_10px.tres` is the project's default text font (`ZenText.font`
falls back to it when unset). It is the font the original Zen Editor drew every
text element with (`GetFontDefault()`), rebuilt glyph for glyph by
`tools/gen_raylib_font.gd` from raylib's own source - regenerate it with that
tool rather than editing the `.tres`.

Source Sans 3 is bundled as an alternative, selectable on the Options screen
(`ZenSettings.BUNDLED_FONTS`). Any installed system font can be picked there too.
