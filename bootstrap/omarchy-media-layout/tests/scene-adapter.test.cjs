const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const base = path.join(__dirname, '..');
function harness() {
  const Allocator = {};
  vm.runInNewContext(fs.readFileSync(path.join(base, 'MediaWidthAllocator.js'), 'utf8'), Allocator);
  const qml = fs.readFileSync(path.join(base, 'FlexibleMediaWidth.qml'), 'utf8');
  const context = {Allocator, anchorId: 'omarchy.clock', edgePadding: 8, laneGap: 8};
  vm.createContext(context);
  // Exercise actual adapter functions; this does not simulate QML notifications.
  vm.runInContext(qml.slice(qml.indexOf('function collectSlots'), qml.lastIndexOf('}')), context);
  const content = {children: []};
  const window = {contentItem: content, width: 1000};
  const widget = {visible: true, fillMediaWidth: true, minimumMediaWidth: 30,
    QsWindow: {window}, bar: {vertical: false, layoutConfig: {center: ['lucky.media', 'omarchy.clock']}}};
  function slot(id, region, item) {
    const result = {moduleName: id, region, activeItem: item, visible: true, parent: content};
    content.children.push(result);
    return result;
  }
  const own = slot('lucky.media', 'center', widget);
  const anchor = slot('omarchy.clock', 'center', {visible: true, implicitWidth: 100});
  anchor.x = 450;
  anchor.width = 100;
  context.widget = widget;
  return {context, content, window, widget, slot, own, anchor};
}
function poison(object, keys) {
  for (const key of keys) Object.defineProperty(object, key, {get() {throw Error(`forbidden read: ${key}`);}});
}
test('disabled own widget returns fallback without touching its implicit width', () => {
  const h = harness();
  h.widget.fillMediaWidth = false;
  poison(h.widget, ['implicitWidth', 'width']);
  assert.equal(h.context.calculateWidth(), -1);
});
test('scene adapter does not read flexible geometry or descend into slot children', () => {
  const h = harness();
  poison(h.widget, ['implicitWidth', 'width']);
  poison(h.own, ['x', 'width', 'implicitWidth', 'children']);
  poison(h.widget.bar, ['shell', 'service']);
  assert.equal(h.context.calculateWidth(), 434);
});
test('empty and invisible slots excluded; fixed width and minimum updates observed on reevaluation', () => {
  const h = harness();
  h.slot('empty', 'left', null);
  h.slot('hidden', 'left', {visible: false, implicitWidth: 900});
  const item = {visible: true, implicitWidth: 100};
  h.slot('fixed', 'left', item);
  assert.equal(h.context.calculateWidth(), 334);
  item.implicitWidth = 120;
  assert.equal(h.context.calculateWidth(), 314);
  h.widget.minimumMediaWidth = 400;
  assert.equal(h.context.calculateWidth(), 400);
});
test('only current contentItem is searched, with absent anchor/own slot fallbacks', () => {
  const h = harness();
  const other = harness();
  other.window.width = 300;
  assert.equal(h.context.calculateWidth(), 434);
  h.content.children = [h.own];
  assert.equal(h.context.calculateWidth(), -1);
  h.content.children = [h.anchor];
  assert.equal(h.context.calculateWidth(), -1);
});
test('window size and fixed anchor geometry update both lane capacities', () => {
  const h = harness();
  h.widget.bar.layoutConfig.center = ['omarchy.clock', 'lucky.media'];
  assert.equal(h.context.calculateWidth(), 434);
  h.window.width = 1200;
  h.anchor.x = 550;
  assert.equal(h.context.calculateWidth(), 534);
  h.widget.bar.vertical = true;
  assert.equal(h.context.calculateWidth(), -1);
});
