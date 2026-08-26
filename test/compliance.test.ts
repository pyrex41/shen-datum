import test from 'node:test';
import assert from 'node:assert/strict';
import { decode } from '../src/parser.js';
import { canonicalEncode, encode } from '../src/encoder.js';

function rejects(input: string | Uint8Array, category?: string) {
  assert.throws(() => decode(input), (error: unknown) => {
    if (!(error instanceof Error)) return false;
    return category === undefined || error.message.startsWith(`${category} `);
  });
}

test('rejects malformed documents and all non-data parenthesized forms', () => {
  rejects('');
  rejects('one two', 'trailing-data');
  rejects('(delete-everything)', 'invalid-tuple');
  rejects('(@p one)', 'unexpected-token');
  rejects('(@q one two)', 'invalid-tuple');
  rejects('[one |]', 'invalid-list-tail');
  rejects('[| one]', 'invalid-list-tail');
  rejects('[one | two | three]', 'invalid-list-tail');
  rejects('[one two', 'unexpected-eof');
  rejects('<one two', 'unexpected-eof');
});

test('enforces maximal-munch and atom separation', () => {
  rejects('12abc', 'invalid-number');
  assert.deepEqual(decode('[one two]').kind, 'list');
  assert.deepEqual(decode('[[one][two]]').kind, 'list');
  rejects('[one\\comment-without-leading-space\ntwo');
});

test('rejects invalid escapes, controls, and Unicode scalar values', () => {
  rejects('"\\x"', 'invalid-escape');
  rejects('"\\uD800"', 'invalid-escape');
  rejects('"\\uDC00"', 'invalid-escape');
  rejects('"\\u{110000}"', 'invalid-escape');
  rejects('"line\u0000break"', 'invalid-escape');
  rejects(new Uint8Array([0xc3, 0x28]), 'invalid-utf8');
});

test('escaped symbols remain symbols and structural delimiters are not bare atoms', () => {
  assert.deepEqual(decode('#s"<="'), { kind: 'symbol', name: '<=' });
  assert.deepEqual(decode('#s"true"'), { kind: 'symbol', name: 'true' });
  rejects('#s""', 'invalid-symbol');
  rejects('#s"bad|name"', 'invalid-symbol');
  rejects('<');
  rejects('a]');
});

test('canonical encoding has no incidental whitespace and preserves distinctions', () => {
  assert.equal(canonicalEncode({ kind: 'list', items: [] }), '[]');
  assert.equal(canonicalEncode({ kind: 'vector', items: [1, 2] }), '<1 2>');
  assert.equal(canonicalEncode({ kind: 'tuple', items: [
    { kind: 'symbol', name: 'one' },
    { kind: 'symbol', name: 'two' },
    { kind: 'symbol', name: 'three' },
  ] }), '(@p one (@p two three))');
  assert.equal(canonicalEncode({ kind: 'list', items: [
    { kind: 'symbol', name: 'one' },
    { kind: 'list', items: [{ kind: 'symbol', name: 'two' }] },
  ] }), '[one [two]]');
  assert.equal(encode({ kind: 'symbol', name: 'true' }), '#s"true"');
  assert.equal(encode({ kind: 'symbol', name: '<=' }), '#s"<="');
  assert.equal(encode(-0), '0');
});

test('canonical numeric spellings normalize signs, zeroes, and exponent case', () => {
  assert.equal(canonicalEncode({ kind: 'number', coefficient: 12300n, scale: 0 }), '12300');
  assert.equal(canonicalEncode({ kind: 'number', value: -0 }), '0');
  assert.equal(canonicalEncode(1000), '1000');
});
