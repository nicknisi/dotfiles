const fs = require('fs')
const path = require('path')
const vm = require('vm')

const moduleBox = { exports: {} }
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../LauncherModel.js'), 'utf8'), { module: moduleBox })
const model = moduleBox.exports

const firefox = { id: 'firefox', name: 'Firefox', genericName: 'Web Browser', comment: 'Browse', keywords: ['internet'] }
const ghostty = { id: 'ghostty', name: 'Ghostty', genericName: 'Terminal', keywords: [] }
const reboot = { id: 'action-reboot', kind: 'action', name: 'Reboot', genericName: 'Restart the computer', keywords: ['power'], order: 3 }

if (!(model.score(firefox, 'fire') < model.score(firefox, 'frfx'))) throw new Error('prefix should beat fuzzy match')
if (model.score(firefox, 'frfx') < 0) throw new Error('fuzzy match should find Firefox')
if (model.score(firefox, 'zzz') !== -1) throw new Error('mismatch should be rejected')
if (model.buildResults('browser', [ghostty, firefox], [reboot])[0].id !== 'firefox') throw new Error('metadata should be searchable')
if (model.buildResults('', [ghostty, firefox], [reboot]).at(-1).id !== 'action-reboot') throw new Error('actions should follow apps before search')

console.log('LAUNCHER_MODEL_TEST_PASS')
