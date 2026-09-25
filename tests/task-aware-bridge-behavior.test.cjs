'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require('typescript');
const source = fs.readFileSync('supabase/functions/pandora-projectos-bridge/index.ts', 'utf8');
const ast = ts.createSourceFile('index.ts', source, ts.ScriptTarget.ES2022, true);
const node = ast.statements.find((entry) => ts.isFunctionDeclaration(entry) && entry.name?.text === 'mergeBoundedMemory');
assert.ok(node, 'Production retrieval function must exist');
const compiled = ts.transpileModule(node.getText(ast), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const context = { exports: {}, TextEncoder, Set, Number, JSON, Error };
vm.runInNewContext(compiled, context);
const merge = context.exports.mergeBoundedMemory;
const normalize = (value) => JSON.parse(JSON.stringify(value));

test('empty typed results retain approved legacy results', () => {
  assert.deepEqual(normalize(merge([], [{ id: 'legacy', body: 'approved architecture' }], 12).items),
    [{ id: 'legacy', body: 'approved architecture' }]);
});
test('typed items take priority without hiding nonduplicate legacy knowledge', () => {
  const result = normalize(merge([{ id: 'same', recordType: 'fact' }], [{ id: 'same' }, { id: 'legacy', record_type: 'architecture' }], 12));
  assert.deepEqual(result.items.map((row) => row.id), ['same', 'legacy']);
  assert.equal(result.items[0].recordType, 'fact');
});
test('UTF-8 bytes, not character count, enforce the response budget', () => {
  const result = normalize(merge([], [{ id: 'large', body: '學'.repeat(100) }, { id: 'small', body: 'ok' }], 12, 100));
  assert.deepEqual(result.items.map((row) => row.id), ['small']);
  assert.equal(result.skipped, 1);
  assert.ok(Buffer.byteLength(JSON.stringify(result.items)) <= 100);
});
test('item cap is enforced and truncation is explicit', () => {
  const result = merge([{ id: 'one' }], [{ id: 'two' }], 1);
  assert.equal(result.items.length, 1);
  assert.equal(result.skipped, 1);
});
test('invalid budgets are rejected rather than silently unbounded', () => {
  for (const value of [0, -1, 51, 1.5, NaN]) assert.throws(() => merge([], [], value));
  assert.throws(() => merge([], [], 12, 999999));
});
test('legacy entries never receive typed policy authority', () => {
  const row = normalize(merge([], [{ id: 'legacy', record_type: 'governance_rule' }], 12).items)[0];
  assert.equal(row.recordType, undefined);
  assert.equal(row.authorizationEffect, undefined);
  assert.match(source, /authorization_effect: typed \? item.authorizationEffect : "none"/);
});
