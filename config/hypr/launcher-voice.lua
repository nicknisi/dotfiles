-- >>> keystroke voice: hold the palette hotkey to dictate (written by Keystroke Settings › Voice)
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("qs ipc call launcher voiceHold"), { long_press = true })
hl.bind("SPACE", hl.dsp.exec_cmd("qs ipc call launcher voiceRelease"), { release = true, ignore_mods = true, submap_universal = true, non_consuming = true })
hl.bind("Super_L", hl.dsp.exec_cmd("qs ipc call launcher voiceRelease"), { release = true, ignore_mods = true, submap_universal = true, non_consuming = true })
hl.bind("Super_R", hl.dsp.exec_cmd("qs ipc call launcher voiceRelease"), { release = true, ignore_mods = true, submap_universal = true, non_consuming = true })
-- <<< keystroke voice
