const test = require('node:test');
const assert = require('node:assert/strict');

const { __test__ } = require('../index.js');

test('asInt truncates numeric values and falls back for invalid input', () => {
  assert.equal(__test__.asInt('42.9', 0), 42);
  assert.equal(__test__.asInt(-13.7, 0), -13);
  assert.equal(__test__.asInt('not-a-number', 9), 9);
});

test('safeText cleans control chars and collapses extra whitespace', () => {
  const cleaned = __test__.safeText('  A\x00  B \n C  ', 'fallback', 64);
  assert.equal(cleaned, 'A B C');
  assert.equal(__test__.safeText('', 'fallback', 64), 'fallback');
});

test('normalizeGangRole maps localized and english aliases', () => {
  assert.equal(__test__.normalizeGangRole('lider'), 'Lider');
  assert.equal(__test__.normalizeGangRole('right hand'), 'Sağ Kol');
  assert.equal(__test__.normalizeGangRole('captain'), 'Kaptan');
  assert.equal(__test__.normalizeGangRole('unknown', 'Üye'), 'Üye');
});

test('resolvePenaltyStatus returns active when penalty expired', () => {
  const now = 1000;
  const active = __test__.resolvePenaltyStatus(
    { status: 'prison', statusUntilEpoch: 900 },
    now,
  );
  assert.deepEqual(active, { status: 'active', statusUntilEpoch: 0 });
});

test('resolvePenaltyStatus keeps penalty when statusUntil is in future', () => {
  const now = 1000;
  const penalized = __test__.resolvePenaltyStatus(
    { status: 'hospital', statusUntilEpoch: 1200 },
    now,
  );
  assert.deepEqual(penalized, { status: 'hospital', statusUntilEpoch: 1200 });
});

test('gangWarPairKey is deterministic independent of side order', () => {
  const a = __test__.gangWarPairKey('gang_alpha', 'gang_beta');
  const b = __test__.gangWarPairKey('gang_beta', 'gang_alpha');
  assert.equal(a, 'gang_alpha__gang_beta');
  assert.equal(a, b);
});
