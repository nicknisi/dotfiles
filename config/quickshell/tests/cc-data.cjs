// lib/CcData.js: what the control center and its sheets draw (PLAN M6,
// control-lock 2 and 3), from plain data, including the [GUESS] rules.
const assert = require('node:assert/strict')
const C = require('../lib/CcData.js')

const now = Date.parse('2026-11-14T10:45:00Z')
const min = 60000

// ---- home: tiles ----
let tiles = C.tiles({ wifi: { present: true, radioOn: true, connected: true, ssid: 'home-5g' }, bt: { present: true, enabled: true, device: 'Headphones' }, tailscale: { installed: true, running: true, state: 'Connected' }, dnd: true })
assert.deepEqual(tiles.map(t => t.key), ['wifi', 'bt', 'ts', 'dnd'])
assert.deepEqual(tiles.map(t => t.sub), ['home-5g', 'Headphones', 'Connected', 'On'], 'the board\'s subs')
assert.ok(tiles.every(t => t.on), 'all on')
tiles = C.tiles({ wifi: { present: true, radioOn: false }, bt: { present: true, enabled: false }, tailscale: { installed: true, running: false }, dnd: false })
assert.deepEqual(tiles.map(t => t.sub), ['Off', 'Off', 'Off', 'Off'])
assert.deepEqual(tiles.map(t => t.icon), ['wifiOff', 'btOff', 'tailscale', 'moon'])
tiles = C.tiles({ wifi: { present: true, radioOn: true, connected: false }, bt: { present: true, enabled: true, settling: true }, tailscale: { installed: true, needsLogin: true, busy: true } })
assert.equal(tiles[0].sub, 'Not connected', 'on but unassociated')
assert.equal(tiles[1].sub, 'On', 'on with nothing connected')
assert.ok(tiles[1].busy && !tiles[1].enabled, 'settling Bluetooth is busy and refuses a toggle')
assert.equal(tiles[2].sub, 'Needs login')
assert.ok(!tiles[2].enabled, 'busy Tailscale refuses a toggle')
tiles = C.tiles({ wifi: { present: false }, bt: { present: false }, tailscale: { installed: false } })
assert.deepEqual(tiles.slice(0, 3).map(t => t.sub), ['No adapter', 'No adapter', 'Not installed'])
assert.ok(tiles.slice(0, 3).every(t => !t.enabled && !t.on))

// ---- levels, minis ----
const levels = C.levels({ volume: { value: 1.4, muted: true, device: 'Speakers' }, brightness: { value: 0.48 } })
assert.equal(levels[0].value, 1, 'clamped')
assert.equal(levels[0].icon, 'volMute')
assert.equal(levels[1].device, 'Built-in')
let minis = C.minis({ awake: { active: true, label: '1 hour' }, hz: 60, scale: 1.5, theme: 'hackerman', recording: true })
assert.deepEqual(minis.map(m => m.key), ['awake', 'power', 'display', 'theme', 'record', 'clipboard'])
assert.deepEqual(minis.map(m => m.sub), ['1 hour', '60 Hz', '1.5× scale', 'hackerman', 'Stop', 'History'])
assert.deepEqual(minis.map(m => m.on), [true, false, false, false, true, false])
minis = C.minis({ awake: { active: false }, scale: 2 })
assert.equal(minis[0].sub, 'Off')
assert.equal(minis[1].sub, 'Auto', 'no rate read yet')
assert.equal(minis[2].sub, '2× scale')

// ---- notes ----
const notes = C.notes({ notifications: [
  { summary: 'Session finished', appName: 'Claude Code', body: 'Island <b>mocks</b> &amp; more', created: now - 2 * min },
  { summary: 'Recording saved', appName: 'capture', body: 'Region recording, 0:42', created: now - 14 * min, critical: true },
  { summary: 'third', appName: 'x', created: now }
], count: 3 }, now)
assert.equal(notes.count, 3)
assert.equal(notes.rows.length, 2, 'two rows on the card')
assert.equal(notes.rows[0].sub, 'Claude Code · Island mocks & more', 'body as one plain line')
assert.deepEqual(notes.rows.map(r => r.time), ['2m', '14m'])
assert.deepEqual(notes.rows.map(r => r.icon), ['sparkle', 'record'], 'the board\'s icons')
assert.ok(notes.rows[1].critical)
assert.equal(C.ago(now - 30000, now), 'now')
assert.equal(C.ago(now - 3 * 60 * min, now), '3h')
assert.equal(C.ago(now - 26 * 60 * min, now), '1d')
assert.equal(C.ago(0, now), '')

// ---- footer, media ----
const footer = C.footer({ user: 'nicknisi', battery: { present: true, percent: 25 }, tray: [{ id: 'op', title: '1Password', icon: 'image://icon/x' }] })
assert.equal(footer.letter, 'N')
assert.equal(footer.battery.text, '25% · on battery', 'the board\'s footer')
assert.equal(C.footer({ battery: { present: true, percent: 80, charging: true } }).battery.text, '80% · charging')
assert.equal(C.footer({ battery: { present: true, percent: 100, pluggedIn: true } }).battery.text, '100% · plugged in')
assert.equal(C.footer({ battery: { present: false } }).battery.visible, false, 'hidden with no battery')
assert.equal(footer.tray[0].title, '1Password')
// The board's battery carries a level mark (M6 review): low, medium, full by level.
assert.equal(footer.battery.icon, 'batteryLow', '25 % is low')
assert.deepEqual([30, 31, 70, 71, 100].map(p => C.batteryIcon({ percent: p })), ['batteryLow', 'batteryMedium', 'batteryMedium', 'batteryFull', 'batteryFull'])
assert.equal(C.batteryIcon({ percent: 50, low: true }), 'batteryLow', 'UPower\'s low wins')
assert.equal(C.batteryIcon({ percent: 10, charging: true }), 'batteryCharging')
let media = C.mediaCard({ title: 'Neon Grid', artist: 'Night Rider', playing: true, position: 102, length: 271, canSeek: true })
assert.equal(media.elapsed, '1:42')
assert.equal(media.total, '4:31')
assert.ok(Math.abs(media.progress - 102 / 271) < 1e-9)
assert.ok(media.canSeek)
media = C.mediaCard(null)
assert.equal(media.title, 'Ready when you are', 'MediaCard.qml\'s empty copy')
assert.ok(!media.canNext && !media.canPrevious)
assert.equal(C.mediaCard({ title: 't', position: 5 }).total, '', 'no length, no times')
// The cover (M10, MediaCard's): MPRIS trackArtUrl through, "" without one.
assert.equal(C.mediaCard({ title: 't', art: 'file:///tmp/cover.png' }).art, 'file:///tmp/cover.png')
assert.equal(C.mediaCard({ title: 't' }).art, '')
assert.equal(C.mediaCard(null).art, '')

// ---- sheets: Battery (M10, BatteryMenu.qml's charge limit) ----
const care = { supported: true, mode: 'Custom', start: 50, end: 80, target: 0, recovery: false }
let bat = C.battery({ present: true, percent: 62, statusText: 'Charging', timeText: '1h 10m', pluggedIn: true, busy: false, error: '', care })
assert.equal(bat.status, 'Charging · 62% · 1h 10m', 'BatteryMenu\'s subtitle')
assert.equal(bat.hasSwitch, false)
assert.equal(bat.footer, '')
assert.deepEqual(bat.groups[0].rows.map(r => [r.key, r.title, r.action]), [['80', 'Top up to 80%', 'topUp'], ['100', 'Charge to 100%', 'topUp']])
assert.deepEqual(bat.groups[1].rows.map(r => r.key), ['care', 'how'])
assert.equal(bat.groups[1].rows[0].sub, 'Battery care: start below 50%, stop at 80%.')
assert.ok(bat.groups[1].rows.every(r => r.inert && r.wrap), 'the hints are inert and wrap')
// Battery.topUp's rules: 80 % needs the 80 % cap and under 75 %, the raw level counts.
const can = src => C.battery(Object.assign({ present: true, percent: 62, pluggedIn: true, care }, src)).groups[0].rows.map(r => r.action === 'topUp')
assert.deepEqual(can({ percent: 76 }), [false, true], 'no 80 % top-up from 75 %')
assert.deepEqual(can({ percent: 79.6, care: Object.assign({}, care, { end: 100 }) }), [false, true], 'no 80 % top-up without the 80 % cap')
assert.deepEqual(can({ percent: 99.6 }), [false, true], 'the raw level, not the rounded one')
assert.deepEqual(can({ pluggedIn: false }), [false, false], 'unplugged')
assert.deepEqual(can({ busy: true }), [false, false], 'busy')
assert.deepEqual(can({ care: Object.assign({}, care, { mode: 'Standard' }) }), [false, false], 'not in Custom mode')
assert.deepEqual(can({ care: { supported: false } }), [false, false], 'unsupported')
assert.ok(C.battery({ present: true, percent: 62, pluggedIn: true, care }).groups[0].rows.every(r => r.action !== '' || (r.inert && r.dim)), 'what cannot run is dim and inert')
assert.equal(C.battery({ present: true, percent: 62, pluggedIn: true, care: { supported: true, mode: 'Standard' } }).groups[1].rows[1].sub,
    'Select Custom charging mode in BIOS to enable battery care.')
assert.equal(C.battery({ present: true, percent: 62, pluggedIn: false, care }).groups[1].rows[1].sub, 'Connect a charger to top up.')
// A top-up running: Cancel; interrupted: Restore; busy: inert.
bat = C.battery({ present: true, percent: 70, pluggedIn: true, care: Object.assign({}, care, { target: 100 }) })
assert.deepEqual(bat.groups[0].rows.map(r => [r.key, r.title, r.action]), [['stop', 'Cancel top-up', 'stop']])
assert.equal(bat.groups[1].rows.map(r => r.key).join(), 'how', 'no care hint while one runs')
bat = C.battery({ present: true, percent: 70, pluggedIn: true, care: Object.assign({}, care, { target: 100, recovery: true }) })
assert.equal(bat.groups[0].rows[0].title, 'Restore battery care')
assert.equal(bat.groups[0].rows[0].sub, 'Top-up was interrupted. Restore battery care below.')
bat = C.battery({ present: true, percent: 70, pluggedIn: true, busy: true, care: Object.assign({}, care, { target: 100 }) })
assert.ok(bat.groups[0].rows[0].inert && bat.groups[0].rows[0].action === '', 'busy: nothing to press')
assert.equal(bat.groups[1].rows[0].title, 'Waiting for authorization')
bat = C.battery({ present: true, percent: 70, error: 'pkexec failed', care })
assert.ok(bat.groups[1].rows.some(r => r.key === 'error' && r.bad && r.sub === 'pkexec failed'), 'the error in bad')
assert.equal(C.battery({ present: false }).groups[0].rows[0].title, 'No battery')
assert.equal(C.sheetName('battery'), 'battery')
assert.equal(C.sheetName('charge'), 'battery')
// Only file, http(s) and data URLs reach the well (M9).
assert.equal(C.mediaCard({ title: 't', art: 'https://i.scdn.co/image/ab67' }).art, 'https://i.scdn.co/image/ab67', 'an http(s) cover')
assert.equal(C.mediaCard({ title: 't', art: 'javascript:alert(1)' }).art, '', 'only file, http(s) and data URLs')

// ---- sheets: Wi-Fi ----
let wifi = C.wifi({ present: true, radioOn: true, portal: false, networks: [
  { ssid: 'home-5g', connected: true, known: true, secured: true, bars: 4 },
  { ssid: 'office', known: true, secured: true, bars: 3 },
  { ssid: 'Cafe', secured: true, bars: 2 },
  { ssid: 'Library', secured: false, bars: 1 }
] })
assert.deepEqual(wifi.groups.map(g => g.label), ['Connected', 'Known', 'Other networks'])
assert.deepEqual(wifi.groups.map(g => g.rows.map(r => r.action)), [['disconnect'], ['connect'], ['passphrase', 'connect']])
assert.deepEqual(wifi.groups[2].rows.map(r => r.icon), ['wifi1', 'wifi1'])
assert.equal(wifi.groups[0].rows[0].icon, 'wifi')
assert.equal(wifi.groups[1].rows[0].icon, 'wifi2')
assert.equal(wifi.groups[0].rows[0].sub, 'Secured', 'no band (PLAN risk 22)')
assert.ok(wifi.groups[2].rows.every(r => r.dim), 'other networks dim')
assert.ok(wifi.groups[1].rows[0].forget, 'a known one can be forgotten')
assert.equal(wifi.status, 'On')
assert.equal(wifi.footer, 'Network settings')
wifi = C.wifi({ present: true, radioOn: true, portal: true, networks: [{ ssid: 'Test Hotel', connected: true, known: true, secured: false, bars: 4 }] })
assert.equal(wifi.groups[0].rows[0].sub, 'Sign-in required', 'the portal shows on the connected row')
assert.equal(wifi.groups[0].rows[0].action, 'portal', 'and pressing it opens the portal, not a disconnect')
assert.equal(C.wifi({ present: true, radioOn: false }).groups[0].rows[0].title, 'Wi-Fi is off')
assert.equal(C.wifi({ present: true, radioOn: true, networks: [] }).groups[0].rows[0].title, 'No networks in range')
assert.ok(!C.wifi({ present: false }).switchEnabled)
assert.equal(C.wifi({ present: true, radioOn: true, networks: [{ ssid: 'x', known: true, busy: true }] }).groups[0].rows[0].sub, 'Connecting…')
// NetMenu's manual sign-in: Limited or Unknown connectivity, no portal reported.
wifi = C.wifi({ present: true, radioOn: true, portal: false, signIn: true, networks: [{ ssid: 'Cafe', connected: true, known: true, bars: 4 }] })
assert.deepEqual(wifi.groups[0].rows.map(r => [r.key, r.action]), [['Cafe', 'disconnect'], ['sign-in', 'portal']])
wifi = C.wifi({ present: true, radioOn: true, portal: true, signIn: true, networks: [{ ssid: 'Cafe', connected: true, known: true, bars: 4 }] })
assert.equal(wifi.groups[0].rows.length, 1, 'a reported portal is the connected row itself')

// ---- Sound ----
const sound = C.sound({ sink: 'Speakers', muted: false,
  sinks: [{ key: '1', name: 'Speakers', transport: 'Built-in', isDefault: true }, { key: '2', name: 'WH-1000XM5', transport: 'Bluetooth', headphones: true }],
  sources: [{ key: '3', name: 'Built-in mic', transport: 'Built-in', isDefault: true }],
  recorders: ['Zoom'],
  streams: [{ key: '4', app: 'Firefox', volume: 0.8 }, { key: '5', app: 'Spotify', volume: 0.5 }, { key: '6', app: 'zoom', volume: 1 }] })
assert.deepEqual(sound.groups.map(g => g.label), ['Output', 'Input', 'Apps'])
assert.deepEqual(sound.groups[0].rows.map(r => [r.on, r.icon]), [[true, 'speaker'], [false, 'headphones']])
assert.equal(sound.groups[1].rows[0].sub, 'In use by Zoom', 'the board\'s input row')
// AudioMenu's faders: the default output and input carry their level, and a
// press mutes them (M6 review).
assert.deepEqual(sound.groups[0].rows.map(r => [r.action, r.slider, r.trail]), [['outputMute', 0, '0'], ['sink', undefined, undefined]])
const sound2 = C.sound({ muted: true, volume: 0.62, micVolume: 0.8, micMuted: true,
  sinks: [{ key: '1', name: 'Speakers', isDefault: true }], sources: [{ key: '3', name: 'Built-in mic', isDefault: true }, { key: '7', name: 'USB mic' }] })
assert.deepEqual(sound2.groups[0].rows.map(r => [r.action, r.slider, r.trail, r.sub, r.icon]), [['outputMute', 0.62, '62', 'Muted', 'volMute']])
assert.deepEqual(sound2.groups[1].rows.map(r => [r.action, r.slider, r.sub, r.icon]), [['micMute', 0.8, 'Muted', 'micOff'], ['source', undefined, 'Built-in', 'mic']])
assert.ok(!sound2.switchOn, 'the header switch is sound on')
assert.deepEqual(sound.groups[2].rows.map(r => r.icon), ['globe', 'music', 'video'])
assert.deepEqual(sound.groups[2].rows.map(r => r.trail), ['80', '50', '100'])
assert.equal(sound.groups[2].rows[0].slider, 0.8)
assert.ok(sound.switchOn, 'sound on while not muted')
assert.equal(sound.footer, '', 'no mixer installed, no footer')
assert.equal(C.sound({ sinks: [{ key: '1', name: 'Speakers', isDefault: true }] }).groups.length, 2, 'Output shows with one sink; Apps hides with no streams')
assert.equal(C.transport({ 'device.api': 'bluez5' }), 'Bluetooth')
assert.equal(C.transport({ 'node.name': 'alsa_output.pci-0000_00_1f.3.hdmi-stereo' }), 'HDMI')
assert.equal(C.transport({ 'device.bus': 'usb' }), 'USB')
assert.equal(C.transport({}), 'Built-in')
assert.equal(C.outputName({ name: 'bluez_output.AA', description: 'WH-1000XM5', props: {} }), 'WH-1000XM5')
assert.equal(C.outputName({ name: 'alsa_output.x', description: 'Headphones', props: { 'device.form-factor': 'headphone' } }), 'Headphones')
assert.equal(C.outputName({ name: 'alsa_output.pci.analog-stereo', description: 'Lunar Lake Speaker', props: {} }), 'Speakers')

// ---- Tailscale ----
const ts = C.tailscale({ installed: true, running: true, state: 'Connected', self: { name: 'milhouse', ipv4: '100.64.0.1' }, exitName: '',
  peers: [{ id: 'a', name: 'riker', os: 'linux', canSend: true }, { id: 'b', name: 'mbp', os: 'macOS' }],
  offline: [{ id: 'c', name: 'pixel', os: 'android', lastSeen: now - 120 * min }] }, now, '')
assert.deepEqual(ts.groups.map(g => g.label), ['This machine', 'Exit node', 'Machines'])
assert.equal(ts.groups[0].rows[0].sub, '100.64.0.1 · this device')
assert.equal(ts.groups[1].rows[0].title, 'None')
assert.equal(ts.groups[1].rows[0].sub, 'Traffic leaves from this network')
assert.deepEqual(ts.groups[2].rows.map(r => [r.title, r.sub, r.icon, r.trail || '', !!r.dim]), [
  ['riker', 'Online', 'server', '●', false], ['mbp', 'Online', 'laptop', '●', false], ['pixel', 'Last seen 2 h ago', 'phone', '', true]], 'the board\'s machines, offline last')
assert.ok(ts.groups[2].rows[0].canSend && !ts.groups[2].rows[2].canSend)
assert.equal(ts.footer, 'Send a file with Taildrop')
assert.ok(ts.footerEnabled, 'enabled whenever an online machine takes files (M6 review)')
assert.ok(!C.tailscale({ installed: true, running: true, busy: true, peers: [{ id: 'a', canSend: true }] }, now).footerEnabled, 'not while Tailscale is busy')
assert.ok(!C.tailscale({ installed: true, running: true, peers: [{ id: 'b' }] }, now).footerEnabled, 'nor with no machine to send to')
const send = C.tailscale({ installed: true, running: true, peers: [{ id: 'a', name: 'riker', os: 'linux', canSend: true }, { id: 'b', name: 'mbp' }] }, now, 'send')
assert.deepEqual(send.groups.map(g => [g.label, g.rows.map(r => [r.key, r.action, r.canSend])]), [['Send to', [['a', 'send', true]]]], 'the pick page lists the machines that take files')
assert.ok(!send.hasSwitch && send.footer === '')
const accounts = C.tailscale({ installed: true, running: true, accounts: [{ id: 'p1', label: 'work', account: 'nick@work', selected: true }, { id: 'p2', label: 'home', account: 'nick@home' }] }, now)
assert.deepEqual(accounts.groups[accounts.groups.length - 1].rows.map(r => [r.key, r.account, r.title, r.sub, r.on, r.action]),
  [['account:p1', 'p1', 'work', 'In use', true, 'account'], ['account:p2', 'p2', 'home', 'nick@home', false, 'account']], 'TailscaleMenu\'s Accounts')
assert.ok(!C.tailscale({ installed: true, running: true, accounts: [{ id: 'p1', selected: true }] }, now).groups.some(g => g.label === 'Accounts'), 'one account is no choice')
const exits = C.tailscale({ running: true, exitName: 'us-nyc', routes: [{ id: 'direct', name: 'Direct connection', detail: 'No exit node' }, { id: 'n', name: 'us-nyc', selected: true, detail: 'Mullvad' }] }, now, 'exits')
assert.equal(exits.groups[0].label, 'Exit node')
assert.deepEqual(exits.groups[0].rows.map(r => r.on), [false, true])
assert.ok(!exits.hasSwitch)
assert.equal(C.tailscale({ installed: true, running: true, exitName: 'us-nyc' }, now).groups[1].rows[0].sub, 'Traffic leaves from us-nyc')
const denied = C.tailscale({ installed: true, accessDenied: true, needsLogin: true, statusError: true }, now)
assert.deepEqual(denied.groups[0].rows.map(r => r.action), ['authorize', 'login'], 'no Start service while access is denied')
const down = C.tailscale({ installed: true, statusError: true, error: 'connection refused', health: ['DNS is not working'] }, now)
assert.deepEqual(down.groups[0].rows.map(r => [r.key, r.action || '', !!r.inert]), [['error', '', true], ['start', 'startService', false], ['health-0', '', true]], 'TailscaleMenu\'s Start service and health lines')
assert.ok(!C.tailscale({ installed: true, statusError: true }, now).switchEnabled, 'no switch while the daemon is unreachable')
assert.ok(!C.tailscale({ installed: false }, now).switchEnabled)

// ---- Bluetooth, notifications, display, awake ----
const bt = C.bluetooth({ present: true, enabled: true, discovering: true,
  connected: [{ key: 'a', name: 'WH-1000XM5', status: 'connected', battery: 80, icon: 'audio-headset' }],
  known: [{ key: 'b', name: 'MX Keys', status: 'paired', battery: -1, icon: 'input-keyboard', paired: true }],
  nearby: [{ key: 'c', name: 'Phone', status: '', icon: 'phone' }] })
assert.deepEqual(bt.groups.map(g => g.label), ['Connected', 'Paired', 'Available', ''])
assert.deepEqual(bt.groups.slice(0, 3).map(g => g.rows[0].icon), ['headphones', 'keyboard', 'phone'])
assert.ok(bt.groups[3].rows[0].inert && /bluetoothctl/.test(bt.groups[3].rows[0].sub), 'BtMenu\'s passkey hint while scanning')
assert.equal(C.bluetooth({ present: true, enabled: true, known: [{ key: 'b', name: 'MX Keys', paired: true }] }).groups.length, 1, 'no hint while not scanning')
assert.deepEqual(C.bluetooth({ present: true, enabled: true, discovering: true }).groups.map(g => g.rows[0].key), ['empty', 'passkey'], 'nothing found yet: the empty note, then the hint')
assert.equal(bt.groups[0].rows[0].trail, '80%')
assert.equal(bt.groups[1].rows[0].trail, '')
assert.ok(bt.groups[1].rows[0].forget && !bt.groups[2].rows[0].forget && !bt.groups[0].rows[0].forget)
assert.equal(bt.groups[2].rows[0].sub, 'Not paired')
assert.equal(bt.status, 'Scanning')
assert.equal(bt.footer, 'Stop scanning')
assert.equal(C.bluetooth({ present: true, enabled: false }).footer, '')
assert.ok(!C.bluetooth({ present: true, settling: true }).switchEnabled)
const ns = C.notifications({ dnd: true, items: [{ summary: 'a', appName: 'Claude Code', body: 'b', created: now - 5 * min }] }, now)
assert.equal(ns.status, 'Do not disturb')
assert.ok(ns.switchOn)
assert.equal(ns.groups[0].rows[0].trail, '5m')
// The history keeps a long body readable: six wrapped lines (M10 review).
assert.ok(ns.groups[0].rows[0].wrap === true && ns.groups[0].rows[0].lines === 6)
assert.equal(ns.footer, 'Clear all')
assert.equal(C.notifications({ items: [] }, now).groups[0].rows[0].title, 'No notifications')
assert.equal(C.notifications({ items: [] }, now).footer, '')
const disp = C.display({ brightness: { value: 0.48 }, barMode: 'island', current: { width: 2880, height: 1800, hz: 120, scale: 1.5 },
  modes: [{ mode: '2880x1800@120', label: '2880×1800 @ 120 Hz', current: true }], scales: [{ value: 1.5, label: '1.5×', current: true }, { value: 2, label: '2×' }] })
assert.deepEqual(disp.groups.map(g => g.label), ['Brightness', 'Bar', 'Mode', 'Scale'])
assert.equal(disp.groups[0].rows[0].trail, '48')
assert.deepEqual(disp.groups[1].rows.map(r => r.key), ['island', 'pill', 'full', 'rail'])
assert.ok(disp.groups[1].rows[0].on)
assert.equal(disp.status, '2880×1800 · 120 Hz · 1.5×')
// M9: with Look.qml's looks, the island's form and look after the Bar.
const L = require('../lib/LookModel.js')
const looks = L.LOOKS.map(k => ({ key: k, title: L.META[k].label, sub: L.META[k].sub }))
const disp9 = C.display({ brightness: { value: 0.48 }, barMode: 'island', islandForm: 'notch', look: 'arcade', looks })
assert.deepEqual(disp9.groups.map(g => g.label), ['Brightness', 'Bar', 'Island form', 'Look'])
assert.deepEqual(disp9.groups[2].rows.map(r => [r.key, r.on, r.action]), [['float', false, 'form'], ['notch', true, 'form']])
assert.deepEqual(disp9.groups[3].rows.map(r => r.key), ['crew', 'phosphor', 'bridge', 'arcade', 'liner', 'outrun'])
assert.deepEqual(disp9.groups[3].rows.filter(r => r.on).map(r => r.key), ['arcade'])
assert.ok(disp9.groups[3].rows.every(r => r.action === 'look' && r.title !== '' && r.sub !== ''))
assert.equal(disp9.groups[3].rows[0].title, 'Crew', 'the plain island is Crew')
const dispDefault = C.display({ barMode: 'island', looks })
const group = (d, label) => d.groups.find(g => g.label === label)
assert.deepEqual([group(dispDefault, 'Island form').rows.find(r => r.on).key, group(dispDefault, 'Look').rows.find(r => r.on).key], ['float', 'crew'], 'defaults: float, crew')
assert.ok(!disp.hasSwitch)
const awake = C.awake({ active: true, selected: 60, status: 'On for 1 hour', options: [{ minutes: 30, label: '30 minutes' }, { minutes: 60, label: '1 hour' }, { minutes: -1, label: 'Until turned off' }] })
assert.deepEqual(awake.groups[0].rows.map(r => r.on), [false, true, false])
assert.equal(awake.status, 'On for 1 hour')

// ---- names ----
assert.equal(C.sheetName('net'), 'wifi')
assert.equal(C.sheetName('audio'), 'sound')
assert.equal(C.sheetName('tailscale'), 'tailscale')
assert.equal(C.sheetName('bogus'), '')
assert.equal(C.scaleText(1.25), '1.25×')
assert.equal(C.lastSeen(0, now), 'Offline')

console.log('CC_DATA_PASS')
