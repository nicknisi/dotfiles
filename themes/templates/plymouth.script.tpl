# {{ name }} — rendered by bin/theme from themes/templates/plymouth.script.tpl.
# Installed by `theme plymouth` as /usr/share/plymouth/themes/nisi/nisi.script.
#
# Text only. Every shape on screen is a glyph from the theme font, scaled where
# a shape is needed, so there are no PNGs to recolour and every colour is a
# colors.toml value. The one trick: Image.Text("█") stretched with Scale() is
# the only way this module draws a solid rectangle.
#
# API as shipped in plymouth's script.so:
#   Image.Text(text, r, g, b, alpha, font, align)   align: left|center|right
#   Sprite.SetPosition(x, y, z)   Image.Scale(w, h)   Math.Min/Max/Clamp

font = "Monaspace Argon 14";
font_small = "Monaspace Argon 11";

Window.SetBackgroundTopColor({{ background_float }});
Window.SetBackgroundBottomColor({{ darker_background_float }});

cx = Window.GetX() + Window.GetWidth() / 2;
cy = Window.GetY() + Window.GetHeight() / 2;

# -- always on: the theme's name, muted, above where the entry appears ------
label.image = Image.Text("{{ name }}", {{ muted_float }}, 1, font_small, "center");
label.sprite = Sprite(label.image);
label.sprite.SetPosition(cx - label.image.GetWidth() / 2, cy - 64, 10000);

# -- the entry: an accent hairline the bullets sit on -----------------------
line.width = 320;
line.image = Image.Text("█", {{ accent_float }}, 1, font);
line.image = line.image.Scale(line.width, 2);
line.sprite = Sprite(line.image);
line.x = cx - line.width / 2;
line.sprite.SetPosition(line.x, cy + 14, 10000);
line.sprite.SetOpacity(0);

# one bullet glyph; a sprite per typed character, left-anchored on the line
bullet.image = Image.Text("●", {{ accent_float }}, 1, font);
bullet.sprites = [];
bullet.step = bullet.image.GetWidth() + 6;
bullet.max = 24;
bullet.y = cy - bullet.image.GetHeight() / 2;

# the prompt plymouth hands over ("A password is required..."), dim, below
hint.sprite = Sprite();
hint.sprite.SetPosition(0, cy + 28, 10000);
hint.sprite.SetOpacity(0);

# wrong passphrase and other messages, in the theme's red, below that
message.sprite = Sprite();
message.sprite.SetPosition(0, cy + 56, 10001);
message.sprite.SetOpacity(0);

fun hide_bullets() {
  for (i = 0; bullet.sprites[i]; i++) {
    bullet.sprites[i].SetOpacity(0);
  }
}

fun display_normal_callback() {
  line.sprite.SetOpacity(0);
  hint.sprite.SetOpacity(0);
  hide_bullets();
}

fun display_password_callback(prompt, bullets) {
  line.sprite.SetOpacity(1);

  hint.image = Image.Text(prompt, {{ dark_foreground_float }}, 1, font_small, "center");
  hint.sprite.SetImage(hint.image);
  hint.sprite.SetX(cx - hint.image.GetWidth() / 2);
  hint.sprite.SetOpacity(1);

  hide_bullets();
  n = Math.Min(bullets, bullet.max);
  for (i = 0; i < n; i++) {
    if (!bullet.sprites[i]) {
      bullet.sprites[i] = Sprite(bullet.image);
      bullet.sprites[i].SetPosition(line.x + 8 + i * bullet.step, bullet.y, 10001);
    }
    bullet.sprites[i].SetOpacity(1);
  }
}

fun display_message_callback(text) {
  message.image = Image.Text(text, {{ red_float }}, 1, font_small, "center");
  message.sprite.SetImage(message.image);
  message.sprite.SetX(cx - message.image.GetWidth() / 2);
  message.sprite.SetOpacity(1);
}

fun hide_message_callback(text) {
  message.sprite.SetOpacity(0);
}

Plymouth.SetDisplayNormalFunction(display_normal_callback);
Plymouth.SetDisplayPasswordFunction(display_password_callback);
Plymouth.SetDisplayMessageFunction(display_message_callback);
Plymouth.SetHideMessageFunction(hide_message_callback);
