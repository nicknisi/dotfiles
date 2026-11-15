# {{ name }} — rendered by bin/theme from themes/templates/plymouth.plymouth.tpl.
# `theme plymouth` installs this as /usr/share/plymouth/themes/nisi/nisi.plymouth
# and rebuilds the initramfs; it is not applied on an ordinary theme switch.
#
# Font= matters beyond looks: the initramfs hook reads it, resolves it with
# fc-match and bundles that one file, and it is the only font Image.Text has at
# boot. The script's "Monaspace Argon 12px" style names only pick the size:
# label-freetype loads this file for any family without "Mono" in it. Monaspace
# Argon covers ● and █, which the script draws with, and every tagline, and
# the script's ● sizes are measured from it. Adwaita Sans, the stock themes'
# choice, has no █.
[Plymouth Theme]
Name=nisi
Description=Boot splash rendered from the active theme pack ({{ name }})
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/nisi
ScriptFile=/usr/share/plymouth/themes/nisi/nisi.script
ConsoleLogBackgroundColor=0x{{ background_strip }}
Font=Monaspace Argon 14
MonospaceFont=Monaspace Argon 12
