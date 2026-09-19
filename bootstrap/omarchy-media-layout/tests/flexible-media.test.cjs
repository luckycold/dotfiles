const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const base = path.join(__dirname, '..');
function allocator() {
  const file = path.join(base, 'MediaWidthAllocator.js');
  assert.ok(fs.existsSync(file), 'allocator implementation exists');
  const ctx = vm.createContext({});
  vm.runInContext(fs.readFileSync(file, 'utf8'), ctx);
  return ctx;
}
const flex = (id, region, minimum = 30) => ({id, region, fill: true, minimum, visible: true});
const fixed = (id, region, width) => ({id, region, width, visible: true});
function config(slots, extra = {}) {
  return {windowWidth: 1000, anchorX: 450, anchorWidth: 100, edge: 8, gap: 8,
    anchorId: 'omarchy.clock', center: ['lucky.media', 'omarchy.clock', {id: 'ma'}], slots, ...extra};
}
test('long and short titles receive the entire gap, not a title-dependent cap', () => {
  const {allocate} = allocator();
  for (const textWidth of [20, 2000]) {
    const slots = [fixed('left', 'left', 100), {...flex('lucky.media', 'center'), textWidth}];
    assert.equal(allocate(config(slots), 1), 334);
  }
});
test('multiple fillers across left and center share equal extra slack above minima', () => {
  const {allocate} = allocator();
  const c = config([flex('outer', 'left', 30), flex('lucky.media', 'center', 50), fixed('fixed', 'left', 100)]);
  assert.equal(allocate(c, 0), 157);
  assert.equal(allocate(c, 1), 177);
});
test('left and right lanes are independent and center order accepts entry objects', () => {
  const {allocate} = allocator();
  const c = config([flex('lucky.media', 'center'), flex('ma', 'center'), fixed('right', 'right', 200)]);
  assert.equal(allocate(c, 0), 434);
  assert.equal(allocate(c, 1), 234);
});
test('hidden entries consume neither width nor a flexible share', () => {
  const {allocate} = allocator();
  const c = config([flex('outer', 'left'), {...flex('lucky.media', 'center'), visible: false}, {...fixed('hidden', 'left', 800), visible: false}]);
  assert.equal(allocate(c, 0), 434);
  assert.equal(allocate(c, 1), -1);
});
test('narrow lane clamps to minima; fixed overflow never produces negative widths', () => {
  const {allocate} = allocator();
  const c = config([flex('lucky.media', 'center', 40), fixed('huge', 'left', 900)]);
  assert.equal(allocate(c, 0), 40);
});
test('unsupported configuration and absent or disabled own slot fall back', () => {
  const {allocate} = allocator();
  const c = config([flex('lucky.media', 'center')]);
  for (const extra of [{vertical: true}, {center: []}, {anchorX: NaN}, {anchorWidth: 0}])
    assert.equal(allocate({...c, ...extra}, 0), -1);
  assert.equal(allocate(c, -1), -1);
  assert.equal(allocate(config([fixed('lucky.media', 'center', 70)]), 0), -1);
});
test('flexible width getters are never evaluated', () => {
  const {allocate} = allocator();
  const item = flex('lucky.media', 'center');
  Object.defineProperty(item, 'width', {get() { throw Error('binding loop'); }});
  Object.defineProperty(item, 'implicitWidth', {get() { throw Error('binding loop'); }});
  assert.equal(allocate(config([item]), 0), 434);
});
test('custom anchor and asymmetric geometry allocate the right lane', () => {
  const {allocate} = allocator();
  const c = config([flex('ma', 'center')], {anchorId: 'custom.clock', center: ['custom.clock', 'ma'], anchorX: 300, anchorWidth: 80});
  assert.equal(allocate(c, 0), 604);
});
test('QML uses local visual children, reactive binding, and no polling or flex geometry', () => {
  const file = path.join(base, 'FlexibleMediaWidth.qml');
  assert.ok(fs.existsSync(file), 'QML implementation exists');
  const qml = fs.readFileSync(file, 'utf8');
  assert.match(qml, /import Quickshell/);
  assert.match(qml, /import qs\.Commons/);
  assert.match(qml, /property string anchorId: "omarchy.clock"/);
  assert.match(qml, /widget\.QsWindow\.window/);
  assert.match(qml, /\.contentItem/);
  assert.match(qml, /\.children/);
  assert.match(qml, /\.activeItem/);
  assert.match(qml, /\.layoutConfig/);
  assert.match(qml, /readonly property real allocatedWidth:/);
  assert.match(qml, /Style\.space\(8\)/);
  assert.doesNotMatch(qml, /Timer\s*\{|\.shell\b|\.service\b|widget\.(implicitWidth|width)|slot\.(x|width|implicitWidth)/);
  assert.match(qml, /if \(fill\)[\s\S]*minimumMediaWidth[\s\S]*else[\s\S]*implicitWidth/);
});
