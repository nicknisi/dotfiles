# Emoji data

`emoji-test.txt` is Unicode's official Emoji 17.0 keyboard/display dataset:
https://www.unicode.org/Public/17.0.0/emoji/emoji-test.txt

Copyright © 2025 Unicode, Inc. Distributed under Unicode License V3, reproduced
in `LICENSE-Unicode.txt` from https://www.unicode.org/license.txt.

`emojis.json` contains all 3,944 fully-qualified entries, in source order.
Each `e` is the source code-point sequence and each `k` is its official English
CLDR short name. Alternate unqualified spellings and standalone components are
excluded, not ordinary emoji or skin-tone/ZWJ variants. The integration tests
reconstruct these records from the source and compare the complete dataset.
