// Executes the same pure ArkTS test suite on Node with Mock storage.
// This checks engine/storage rules; it does not emulate ArkUI or native Preferences.
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const assert = require('node:assert/strict');
const tsPath = process.argv[2];
if (!tsPath) {
  console.error('Usage: node scripts/test-host.cjs <DevEco tools/ohpm/node_modules/typescript>');
  process.exit(2);
}
const ts = require(path.resolve(tsPath));
const cases = [];
const hypium = {
  describe: (name, body) => body(),
  it: (name, filter, body) => cases.push({ name, body }),
  expect: actual => ({
    assertTrue: () => assert.equal(actual, true),
    assertFalse: () => assert.equal(actual, false),
    assertEqual: expected => assert.deepEqual(actual, expected)
  })
};
const originalLoad = Module._load;
Module._load = function (id, parent, isMain) {
  if (id === '@ohos/hypium') return hypium;
  return originalLoad.call(this, id, parent, isMain);
};
require.extensions['.ets'] = (module, filename) => {
  const source = fs.readFileSync(filename, 'utf8');
  const result = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }, fileName: filename + '.ts'
  });
  module._compile(result.outputText, filename);
};
require(path.join(__dirname, '../entry/src/test/Story.test.ets')).default();
(async () => {
  let failures = 0;
  for (const test of cases) {
    try { await test.body(); console.log('PASS ' + test.name); }
    catch (error) { failures++; console.error('FAIL ' + test.name + '\n' + error.stack); }
  }
  console.log(`${cases.length - failures}/${cases.length} passed (host Mock suite)`);
  process.exitCode = failures ? 1 : 0;
})();
