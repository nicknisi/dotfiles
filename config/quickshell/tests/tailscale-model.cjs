const assert = require('assert')
const fs = require('fs')
const path = require('path')
const vm = require('vm')

const moduleBox = { exports: {} }
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../TailscaleModel.js'), 'utf8'), { module: moduleBox, console })
const model = moduleBox.exports

function bad(fn, text) {
  assert.throws(fn, error => error && error.message.includes(text))
}

bad(() => model.parseStatus(''), 'empty status')
bad(() => model.parseStatus('{'), 'invalid status')
bad(() => model.parseStatus('[]'), 'object')
bad(() => model.parseStatus('{"Peer":[]}'), 'BackendState')
bad(() => model.parseAccounts('{'), 'invalid accounts')
bad(() => model.parseAccounts('{}'), 'array')

const status = model.parseStatus(JSON.stringify({
  BackendState: 'Running',
  AuthURL: 'https://login.tailscale.com/a/abc',
  CurrentTailnet: { MagicDNSSuffix: 'tail.example.ts.net' },
  Self: {
    HostName: 'localhost',
    DNSName: 'laptop.tail.example.ts.net.',
    TailscaleIPs: ['100.74.97.73', 'fd7a:115c:a1e0::1'],
    UserID: 1001,
    CapMap: { 'https://tailscale.com/cap/file-sharing': null }
  },
  Health: ['warn'],
  Peer: {
    zed: {
      HostName: 'zed',
      DNSName: 'zed.tail.example.ts.net.',
      TailscaleIPs: ['100.1.1.2'],
      Online: true,
      OS: 'linux',
      UserID: 2002,
      TaildropTarget: 1,
      ExitNodeOption: true
    },
    alpha: {
      HostName: 'alpha',
      DNSName: 'alpha.tail.example.ts.net.',
      TailscaleIPs: ['100.1.1.1', 'fd7a:115c:a1e0::2'],
      Online: true,
      OS: 'macos',
      UserID: 1001
    },
    otherOwnerOldDaemon: {
      HostName: 'other',
      DNSName: 'other.tail.example.ts.net.',
      TailscaleIPs: ['100.1.1.3'],
      Online: true,
      OS: 'linux',
      UserID: 2002
    },
    denied: {
      HostName: 'denied',
      DNSName: 'denied.tail.example.ts.net.',
      TailscaleIPs: ['100.1.1.4'],
      Online: true,
      OS: 'linux',
      UserID: 1001,
      TaildropTarget: 7
    },
    zeroFallback: {
      HostName: 'tail0',
      DNSName: 'tail0.tail.example.ts.net.',
      TailscaleIPs: ['100.1.1.6'],
      Online: true,
      OS: 'linux',
      UserID: 1001,
      TaildropTarget: 0
    },
    offlineSelectedExit: {
      HostName: 'exit-old',
      DNSName: 'exit-old.tail.example.ts.net.',
      TailscaleIPs: ['100.1.1.5'],
      Online: false,
      OS: 'linux',
      UserID: 1001,
      ExitNodeOption: true,
      ExitNode: true
    },
    mullvad: {
      HostName: 'us-nyc-wg-001',
      DNSName: 'us-nyc-wg-001.mullvad.ts.net.',
      TailscaleIPs: ['100.64.1.1'],
      Online: true,
      OS: 'linux',
      ExitNodeOption: true
    }
  }
}))

assert.equal(status.backendState, 'Running')
assert.equal(status.running, true)
assert.equal(status.needsLogin, false)
assert.equal(status.authUrl, 'https://login.tailscale.com/a/abc')
assert.deepEqual(status.self, { name: 'laptop', dns: 'laptop.tail.example.ts.net', ipv4: '100.74.97.73', ipv6: 'fd7a:115c:a1e0::1', userId: '1001' })
assert.equal(status.fileSharing, true)
assert.deepEqual(status.health, ['warn'])
assert.equal(status.tailnet, 'tail.example.ts.net')
assert.deepEqual(status.peers.map(peer => peer.name), ['alpha', 'denied', 'other', 'tail0', 'zed'])
assert.deepEqual(status.peers.map(peer => peer.canSend), [true, false, false, true, true])
assert.deepEqual(status.exitNodes.map(peer => peer.name), ['exit-old', 'zed'])
assert.equal(status.exitNode.name, 'exit-old')
assert.equal(status.exitNode.online, false)
assert.equal(status.peers.some(peer => peer.mullvad), false)

const stopped = model.parseStatus(JSON.stringify({
  BackendState: 'Stopped',
  Self: { UserID: 1001, Capabilities: ['https://tailscale.com/cap/file-sharing'] },
  Peer: {
    alpha: { HostName: 'alpha', DNSName: 'alpha.tail.', TailscaleIPs: ['100.1.1.1'], Online: true, UserID: 1001 }
  }
}))
assert.equal(stopped.running, false)
assert.equal(stopped.fileSharing, false)
assert.equal(stopped.peers[0].canSend, false)

assert.deepEqual(model.parseAccounts(JSON.stringify([
  { id: 'home', nickname: 'Home', account: 'me@example', selected: true },
  { ID: 'work', Name: 'Work', LoginName: 'me@work', Selected: false },
  { id: 'cli', profileName: 'CLI', user: 'cli@example', current: true }
])), [
  { id: 'home', label: 'Home', account: 'me@example', selected: true },
  { id: 'work', label: 'Work', account: 'me@work', selected: false },
  { id: 'cli', label: 'CLI', account: 'cli@example', selected: true }
])

const exitNodes = model.parseExitNodes(`
 IP                  HOSTNAME                         COUNTRY            CITY                   STATUS
 100.65.216.13       au-adl-wg-301.mullvad.ts.net     Australia          Any                    -
 100.65.216.13       au-adl-wg-301.mullvad.ts.net     Australia          Adelaide               offline
 100.70.240.117      au-bne-wg-301.mullvad.ts.net     Australia          Brisbane               -
 100.66.11.119       dk-cph-wg-001.mullvad.ts.net     Denmark            Copenhagen             selected
 100.66.11.120       dk-cph-wg-002.mullvad.ts.net     Denmark            Copenhagen             -
 100.101.10.10       us-chi-wg-001.mullvad.ts.net     United States      Chicago                -
 100.102.10.10       us-nyc-wg-001.mullvad.ts.net     United States      New York               active
 100.103.10.10       us-nyc-wg-002.mullvad.ts.net     United States      New York               -
 100.1.2.3           office.tailnet.ts.net             Denmark            Office                 selected
`)
assert.deepEqual(exitNodes, [
  { id: 'mullvad-region:Australia\nAdelaide', name: 'Adelaide, Australia', target: '100.65.216.13', country: 'Australia', city: 'Adelaide', selected: false },
  { id: 'mullvad-region:Australia\nBrisbane', name: 'Brisbane, Australia', target: '100.70.240.117', country: 'Australia', city: 'Brisbane', selected: false },
  { id: 'mullvad-region:Denmark\nCopenhagen', name: 'Copenhagen, Denmark', target: '100.66.11.119', country: 'Denmark', city: 'Copenhagen', selected: true },
  { id: 'mullvad-region:United States\nChicago', name: 'Chicago, United States', target: '100.101.10.10', country: 'United States', city: 'Chicago', selected: false },
  { id: 'mullvad-region:United States\nNew York', name: 'New York, United States', target: '100.102.10.10', country: 'United States', city: 'New York', selected: true }
])
assert.equal(exitNodes[0].selected, false)

assert.equal(model.authLink('open https://login.tailscale.com/a/abc.'), 'https://login.tailscale.com/a/abc')
assert.equal(model.authLink('open http://127.0.0.1:8080/login'), 'http://127.0.0.1:8080/login')
assert.equal(model.authLink('javascript:alert(1)'), '')
assert.equal(model.authLink('https://'), '')
assert.equal(model.authLink('https://trusted.example@evil.example/a'), '')
assert.equal(model.authLink('https://trusted.example\\\\evil.example/a'), '')
bad(() => model.parseAccounts('"abc"'), 'array')
const vpn = model.parseStatus(JSON.stringify({ BackendState: 'Running', Peer: {
  vpn: { DNSName: 'test.mullvad.ts.net.', ExitNode: true, ExitNodeOption: true, Online: false }
}}))
assert.equal(vpn.exitNode.mullvad, true)
assert.equal(vpn.peers.length, 0)

assert.equal(model.filePath('file:///tmp/a%20b/%23snow-%E2%98%83.txt'), '/tmp/a b/#snow-☃.txt')
assert.equal(model.filePath('file://localhost/tmp/a%23b'), '/tmp/a#b')
assert.equal(model.filePath('https://example.com/tmp/a'), '')
assert.equal(model.filePath('file://example.com/tmp/a'), '')
assert.equal(model.filePath('file:///tmp/%E0%A4%A'), '')
assert.equal(model.filePath('file:///tmp/bad%00name'), '')
console.log('TAILSCALE_MODEL_PASS')
