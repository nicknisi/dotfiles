const fs = require('fs')
const path = require('path')
const vm = require('vm')

const moduleBox = { exports: {} }
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../ClipboardModel.js'), 'utf8'), { module: moduleBox })
const model = moduleBox.exports

const text = model.entry('1', 'copied text')
const image = model.entry('2', '[[ binary data 3.2 MiB png 1920x1080 ]]')
const video = model.entry('3', '[[ binary data 42 MiB mp4 ]]')

if (text.kind !== 'text') throw new Error('plain text should remain text')
if (image.kind !== 'image' || image.extension !== 'png' || image.mime !== 'image/png') throw new Error('PNG should expose a typed image thumbnail')
if (video.kind !== 'video' || video.extension !== 'mp4' || video.mime !== 'video/mp4') throw new Error('MP4 should expose typed video metadata')
if (model.filter([text, image, video], 'image')[0].id !== '2') throw new Error('media kind should be searchable')
if (model.filter(Array(101).fill(text), '').length !== 100) throw new Error('results should stay bounded')

console.log('CLIPBOARD_MODEL_TEST_PASS')
