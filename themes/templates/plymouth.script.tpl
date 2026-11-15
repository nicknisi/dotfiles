# {{ name }} — rendered by bin/theme from themes/templates/plymouth.script.tpl.
# Installed by `theme plymouth` as /usr/share/plymouth/themes/nisi/nisi.script.
#
# The Boot board of the island shell: the LUKS passphrase goes into a capsule
# the size of the island at rest, centred, with the pack's tagline under it.
# Typing shows the hostname and a dot per character; a wrong passphrase rings
# the capsule in the bad colour and shakes it; once one is accepted the
# hostname centres and boot progress runs along the capsule's bottom edge.
#
# Text only. Every shape is a glyph from the theme font, so there are no PNGs
# to recolour and every colour is a token bin/theme-color derives from the
# pack (the shell's rules, shared with Quickshell and the mocks):
#   rectangle   the inside of a █, cropped clear of its antialiased first
#               column, then scaled. Scaling the whole glyph smears that
#               column into a fade a dozen pixels long.
#   round end   a ●, drawn at the size whose circle has the capsule's
#               diameter and placed by the circle's measured centre (glyphs()).
#               Opaque capsules overlap it with the body; the translucent
#               shadow uses half circles (see capsule()).
#
# API as shipped in plymouth's script.so (26.x):
#   Image.Text(text, r, g, b, alpha, font, align)   Image.Crop(x, y, w, h)
#   Image.Scale(w, h)   Sprite.SetPosition(x, y, z)   Math.Int/Min/Max
# Sizes are logical pixels. On milhouse plymouth picks device scale 2, so the
# window is 1440x900 like the board; with DeviceScale=1 it is 2880x1800 and
# everything here draws at s = 2 instead of being upscaled.

Window.SetBackgroundTopColor({{ background_float }});
Window.SetBackgroundBottomColor({{ darker_float }});

host = "{{ hostname_str }}";
tagline = "{{ tagline_str }}";
# what cryptsetup prints on a wrong passphrase. plymouth never shows it (the
# client re-asks with the same prompt), so the splash says it itself
wrong_text = "No key available with this passphrase.";
shadow_alpha = {{ shadow_alpha }};

fun pick_scale() {
  if (Window.GetWidth() >= 2560 && Window.GetHeight() >= 1600) return 2;
  return 1;
}

# ● in Monaspace Argon 1.400 under plymouth's label-freetype, measured: font
# size in px, the circle's diameter, and its centre inside the label image.
# h is the capsule height each was picked for. Re-measure if the font changes.
fun glyphs(s) {
  local.t = [];
  if (s == 2) {
    t.ring.px = 150; t.ring.h = 76; t.ring.d = 76.08; t.ring.cx = 46.49; t.ring.cy = 87.06;
    t.fill.px = 142; t.fill.h = 72; t.fill.d = 72.03; t.fill.cx = 44.01; t.fill.cy = 83.08;
    t.dot.px = 28;   t.dot.h = 14;  t.dot.d = 14.11;  t.dot.cx = 8.67;   t.dot.cy = 16.92;
  } else {
    t.ring.px = 75;  t.ring.h = 38; t.ring.d = 37.96; t.ring.cx = 23.25; t.ring.cy = 43.99;
    t.fill.px = 71;  t.fill.h = 36; t.fill.d = 35.93; t.fill.cx = 22.00; t.fill.cy = 42.04;
    t.dot.px = 14;   t.dot.h = 7;   t.dot.d = 7.02;   t.dot.cx = 4.33;   t.dot.cy = 8.55;
  }
  return t;
}

fun font(px) {
  return "Monaspace Argon " + px + "px";
}

fun solid(r, g, b, w, h) {
  local.blk = Image.Text("█", r, g, b, 1, "Monaspace Argon 40px");
  return blk.Crop(3, 3, blk.GetWidth() - 6, blk.GetHeight() - 6).Scale(w, h);
}

# a sprite that moves with the capsule: kept with its offset from the
# capsule's top-left so the shake can move them together
fun attach(sprite, rx, ry, z) {
  ui.att[ui.n] = sprite;
  ui.ax[ui.n] = rx;
  ui.ay[ui.n] = ry;
  ui.n++;
  sprite.SetPosition(ui.x + rx, ui.y + ry, z);
  return sprite;
}

# A w x h capsule at (rx, ry) from the capsule origin: a circle at each end
# and a █ body from centre to centre. gl is a glyphs() entry; a capsule of
# another height scales that circle, which only the soft shadow does.
#
# An opaque capsule overlaps its circles with the body. A translucent one
# (the shadow) cannot, or the overlap shows twice as dark, so it uses half
# circles. Only for black: Image.Crop composites onto a transparent buffer
# premultiplying again, which darkens any colour's antialiased edge into a
# grey fringe (black has no colour to darken).
fun capsule(gl, rx, ry, w, h, r, g, b, alpha, z) {
  local.img = Image.Text("●", r, g, b, 1, font(gl.px));
  local.f = 1;
  if (h != gl.h) {
    f = h / gl.d;
    img = img.Scale(Math.Int(img.GetWidth() * f + 0.5), Math.Int(img.GetHeight() * f + 0.5));
  }
  local.ccx = gl.cx * f;
  local.ccy = gl.cy * f;
  local.cut = Math.Int(ccx + 0.5);
  local.lx = Math.Int(h / 2 - ccx + 0.5);
  local.ly = Math.Int(h / 2 - ccy + 0.5);
  local.rrx = Math.Int(w - h / 2 - ccx + 0.5);
  local.k = [];
  if (alpha < 1) {
    k.l = attach(Sprite(img.Crop(0, 0, cut, img.GetHeight())), rx + lx, ry + ly, z);
    k.r = attach(Sprite(img.Crop(cut, 0, img.GetWidth() - cut, img.GetHeight())), rx + rrx + cut, ry + ly, z);
  } else {
    k.l = attach(Sprite(img), rx + lx, ry + ly, z);
    k.r = attach(Sprite(img), rx + rrx, ry + ly, z);
  }
  k.b = attach(Sprite(solid(r, g, b, rrx - lx, h)), rx + lx + cut, ry, z);
  capsule_opacity(k, alpha);
  return k;
}

fun capsule_opacity(k, a) {
  k.l.SetOpacity(a);
  k.b.SetOpacity(a);
  k.r.SetOpacity(a);
}

fun label(text, r, g, b, px) {
  return Image.Text(text, r, g, b, 1, font(px));
}

fun build() {
  global.ui = [];
  ui.n = 0;
  ui.s = pick_scale();
  ui.gl = glyphs(ui.s);
  local.s = ui.s;
  ui.w = 360 * s;
  ui.h = 38 * s;
  ui.x = Math.Int(Window.GetX() + Window.GetWidth() / 2 - ui.w / 2);
  ui.y = Math.Int(Window.GetY() + Window.GetHeight() / 2 - ui.h / 2);
  ui.dx = 0;

  # soft shadow, 0 10px 28px in the mock: six capsules from 10px inside the
  # shape to 15px outside, faint each, so it is about half dark at the edge
  # and gone 15px out, like a 28px blur
  for (local.i = 0; i < 6; i++) {
    local.sp = (i * 5 - 10) * s;
    ui.shadow[i] = capsule(ui.gl.ring, -sp, 10 * s - sp, ui.w + 2 * sp, ui.h + 2 * sp, 0, 0, 0, shadow_alpha / 6, 5);
  }
  # 1px ring: an outer capsule in the ring colour under the surface capsule
  ui.ring = capsule(ui.gl.ring, 0, 0, ui.w, ui.h, {{ hairline_float }}, 1, 10);
  ui.ring_bad = capsule(ui.gl.ring, 0, 0, ui.w, ui.h, {{ bad_float }}, 1, 11);
  capsule_opacity(ui.ring_bad, 0);
  ui.fill = capsule(ui.gl.fill, s, s, ui.w - 2 * s, ui.h - 2 * s, {{ surface_float }}, 1, 12);

  # typing: hostname at the left, then a dot per character
  local.pad = 16 * s;
  ui.host_l = label(host, {{ ink_dim_float }}, 12 * s);
  ui.host_left = attach(Sprite(ui.host_l), pad, Math.Int((ui.h - ui.host_l.GetHeight()) / 2), 20);
  ui.dot_img = Image.Text("●", {{ accent_float }}, 1, font(ui.gl.dot.px));
  ui.dot_x = pad + ui.host_l.GetWidth() + 14 * s;
  ui.dot_step = 13 * s;
  ui.dot_max = Math.Int((ui.w - pad - ui.dot_x + 6 * s) / ui.dot_step);
  ui.dot_rx = Math.Int(3.5 * s - ui.gl.dot.cx + 0.5);
  ui.dot_ry = Math.Int(ui.h / 2 - ui.gl.dot.cy + 0.5);
  ui.dots_made = 0;

  # unlocking: hostname centred, progress along the bottom edge
  ui.host_center = attach(Sprite(ui.host_l), Math.Int((ui.w - ui.host_l.GetWidth()) / 2),
                          Math.Int((ui.h - ui.host_l.GetHeight()) / 2), 20);
  ui.bar_w = ui.w - 2 * pad;
  ui.bar_y = ui.h - 9 * s;
  ui.track = attach(Sprite(solid({{ fill_low_float }}, ui.bar_w, 2 * s)), pad, ui.bar_y, 20);
  ui.bar_patch = solid({{ accent_float }}, 1, 2 * s);
  ui.bar = attach(Sprite(), pad, ui.bar_y, 21);

  # under the capsule (it stays put while the capsule shakes)
  ui.under_y = ui.y + 53 * s;
  if (tagline != "") {
    ui.tag = Sprite(label(tagline, {{ ink_dim_float }}, 13 * s));
    ui.tag.SetPosition(Math.Int(Window.GetX() + Window.GetWidth() / 2 - ui.tag.GetImage().GetWidth() / 2), ui.under_y, 20);
  }
  ui.wrong = Sprite(label(wrong_text, {{ bad_float }}, 13 * s));
  ui.wrong.SetPosition(Math.Int(Window.GetX() + Window.GetWidth() / 2 - ui.wrong.GetImage().GetWidth() / 2), ui.under_y, 21);
  ui.msg = Sprite();
  ui.msg.SetPosition(0, ui.under_y, 21);
}

# -- state --------------------------------------------------------------------
# idle      before the prompt, and on shutdown: hostname centred
# typing    the prompt is up
# wrong     the prompt came back after an answer: plymouth's only sign of a
#           wrong passphrase (Enter -> display normal -> cryptsetup fails ->
#           the client asks again with the same prompt)
# unlocking an answer is in and no prompt followed
st.phase = "idle";
st.bullets = 0;
st.message = 0;
st.shake = -1;
st.t0 = -1;
st.duration = 0;
st.progress = 0;
st.p0 = 0;
st.shown = 0;

fun show_dots(n) {
  n = Math.Min(n, ui.dot_max);
  for (local.i = 0; i < ui.dot_max; i++) {
    if (i < n) {
      if (!ui.dot[i]) {
        ui.dot[i] = attach(Sprite(ui.dot_img), ui.dot_x + i * ui.dot_step + ui.dot_rx, ui.dot_ry, 21);
      }
      ui.dot[i].SetOpacity(1);
    } else if (ui.dot[i]) {
      ui.dot[i].SetOpacity(0);
    }
  }
}

fun set_bar(f) {
  local.w = Math.Int(ui.bar_w * Math.Clamp(f, 0, 1) + 0.5);
  if (w < 1) {
    ui.bar.SetOpacity(0);
  } else {
    ui.bar.SetImage(ui.bar_patch.Scale(w, 2 * ui.s));
    ui.bar.SetOpacity(1);
  }
}

fun render() {
  local.p = st.phase;
  local.typing = (p == "typing" || p == "wrong");
  ui.host_left.SetOpacity(typing);
  if (typing) show_dots(st.bullets); else show_dots(0);
  ui.host_center.SetOpacity(!typing);
  ui.track.SetOpacity(p == "unlocking");
  if (p == "unlocking") set_bar(st.shown); else ui.bar.SetOpacity(0);
  capsule_opacity(ui.ring_bad, p == "wrong");
  ui.wrong.SetOpacity(p == "wrong");
  ui.msg.SetOpacity(p != "wrong" && st.message);
  if (ui.tag) ui.tag.SetOpacity(p != "wrong" && !st.message);
}

fun move_capsule(dx) {
  for (local.i = 0; i < ui.n; i++) {
    ui.att[i].SetX(ui.x + ui.ax[i] + dx);
  }
}

build();
render();

# -- callbacks ----------------------------------------------------------------

fun display_normal_callback() {
  if (st.phase == "typing" || st.phase == "wrong") {
    st.phase = "unlocking";
    st.t0 = -1;
    st.p0 = st.progress;
    st.shown = 0;
  }
  render();
}

fun display_password_callback(prompt, bullets) {
  if (st.phase == "unlocking") {
    st.phase = "wrong";
    st.shake = 0;
  } else if (st.phase == "wrong" && bullets > 0) {
    st.phase = "typing";
  } else if (st.phase == "idle") {
    st.phase = "typing";
  }
  st.bullets = bullets;
  render();
}

fun display_message_callback(text) {
  ui.msg.SetImage(label(text, {{ ink_dim_float }}, 13 * ui.s));
  ui.msg.SetX(Math.Int(Window.GetX() + Window.GetWidth() / 2 - ui.msg.GetImage().GetWidth() / 2));
  st.message = 1;
  render();
}

fun hide_message_callback(text) {
  st.message = 0;
  render();
}

fun boot_progress_callback(duration, progress) {
  st.duration = duration;
  st.progress = progress;
}

# the mock's shake: 0.42s through these offsets (px) at these fractions,
# each step eased in and out
shake_x[0] = 0;  shake_x[1] = -9;   shake_x[2] = 8;   shake_x[3] = -6;
shake_x[4] = 4;  shake_x[5] = -2;   shake_x[6] = 0;
shake_t[0] = 0;  shake_t[1] = 0.15; shake_t[2] = 0.3; shake_t[3] = 0.45;
shake_t[4] = 0.6; shake_t[5] = 0.75; shake_t[6] = 1;
shake_frames = 21; # 0.42s at plymouth's 50 Hz

fun refresh_callback() {
  if (st.shake >= 0) {
    local.t = st.shake / shake_frames;
    if (t >= 1) {
      st.shake = -1;
      move_capsule(0);
    } else {
      local.seg = 0;
      while (shake_t[seg + 1] <= t) seg++;
      local.f = (t - shake_t[seg]) / (shake_t[seg + 1] - shake_t[seg]);
      f = f * f * (3 - 2 * f);
      move_capsule(Math.Int((shake_x[seg] + (shake_x[seg + 1] - shake_x[seg]) * f) * ui.s + 0.5));
      st.shake++;
    }
  }
  if (st.phase == "unlocking") {
    # boot progress from the moment of unlock, under a floor that eases out
    # over 2.4s: without a stored boot time plymouth assumes 60s, so in the
    # initramfs the raw value barely moves before the splash quits
    if (st.t0 < 0) st.t0 = st.duration;
    local.t = Math.Clamp((st.duration - st.t0) / 2.4, 0, 1);
    local.ease = 1 - (1 - t) * (1 - t) * (1 - t);
    local.real = 0;
    if (st.p0 < 1) real = (st.progress - st.p0) / (1 - st.p0);
    local.target = Math.Max(0.85 * ease, real);
    st.shown = st.shown + (target - st.shown) * 0.2;
    set_bar(st.shown);
  }
}

fun quit_callback() {
  if (st.phase == "unlocking") set_bar(1);
}

fun hotplug_callback() {
  build();
  render();
}

Plymouth.SetDisplayNormalFunction(display_normal_callback);
Plymouth.SetDisplayPasswordFunction(display_password_callback);
Plymouth.SetDisplayMessageFunction(display_message_callback);
Plymouth.SetHideMessageFunction(hide_message_callback);
Plymouth.SetBootProgressFunction(boot_progress_callback);
Plymouth.SetRefreshFunction(refresh_callback);
Plymouth.SetQuitFunction(quit_callback);
Plymouth.SetDisplayHotplugFunction(hotplug_callback);
