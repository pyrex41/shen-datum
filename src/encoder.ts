/** SDN encoder (version 0.1).
 *
 * Values are accepted either as JavaScript primitives/arrays or as tagged
 * objects used by a decoder.  Tagged objects may use `type` or `_tag` and
 * the conventional `value`/`items`/`tail` fields; this keeps the encoder
 * independent of a particular host representation in types.ts.
 */

export interface EncodeOptions { canonical?: boolean }

const BARE = /^[A-Za-z=\-*\/+_?$!@~.&%'#`;:][A-Za-z0-9=\-*\/+_?$!@~.&%'#`;:]*$/;
const NUMBER = /^[+-]?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$/;

function tag(v: any): string | undefined {
  return v && typeof v === 'object' ? (v.type ?? v._tag ?? v.kind) : undefined;
}
function field(v: any, ...names: string[]): any {
  for (const n of names) if (v && v[n] !== undefined) return v[n];
  return undefined;
}

function escapeString(s: string): string {
  let out = '"';
  for (let i = 0; i < s.length; i++) {
    const cp = s.codePointAt(i)!;
    if (cp > 0xffff) i++;
    if (cp >= 0xd800 && cp <= 0xdfff) throw new TypeError('invalid Unicode scalar value');
    switch (cp) {
      case 0x22: out += '\\\"'; break;
      case 0x5c: out += '\\\\'; break;
      case 0x08: out += '\\b'; break;
      case 0x0c: out += '\\f'; break;
      case 0x0a: out += '\\n'; break;
      case 0x0d: out += '\\r'; break;
      case 0x09: out += '\\t'; break;
      case 0x2f: out += '\\/'; break;
      default:
        if (cp < 0x20) out += `\\u${cp.toString(16).padStart(4, '0')}`;
        else out += String.fromCodePoint(cp);
    }
  }
  return out + '"';
}

function numberText(n: number | bigint | string): string {
  if (typeof n === 'bigint') return n.toString();
  const raw = typeof n === 'string' ? n : Object.is(n, -0) ? '0' : n.toString();
  if (typeof n === 'number' && !Number.isFinite(n)) throw new TypeError('unsupported numeric value');
  if (!NUMBER.test(raw) && !/^[+-]?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$/.test(raw))
    throw new TypeError('invalid number');
  let s = raw;
  let [mant, exp] = s.split(/[eE]/);
  if (exp !== undefined) {
    exp = exp.replace(/^\+/, '').replace(/^-?0+(?=\d)/, (m) => m.startsWith('-') ? '-0' : '0');
    if (exp === '0' || exp === '-0') exp = undefined;
  }
  if (mant.includes('.')) {
    mant = mant.replace(/(\.\d*?[1-9])0+$/, '$1').replace(/\.0*$/, '');
    if (mant === '-0' || mant === '+0' || mant === '') mant = '0';
  }
  s = mant + (exp !== undefined ? 'e' + exp : '');
  if (s.startsWith('+')) s = s.slice(1);
  return s;
}

function symbolText(name: string): string {
  if (typeof name !== 'string' || !name.length) throw new TypeError('invalid symbol');
  return BARE.test(name) && name !== 'true' && name !== 'false' && !NUMBER.test(name)
    ? name : '#s' + escapeString(name);
}

function encodeValue(v: any): string {
  if (v === null || v === undefined) throw new TypeError('unsupported runtime value');
  const t = tag(v);
  if (t === 'symbol' || t === 'Symbol') return symbolText(field(v, 'name', 'value'));
  if (t === 'string' || t === 'String') return escapeString(String(field(v, 'value', 'text')));
  if (t === 'boolean' || t === 'Boolean') return field(v, 'value') ? 'true' : 'false';
  if (t === 'number' || t === 'Number' || t === 'integer' || t === 'decimal') return numberText(field(v, 'value'));
  if (t === 'vector' || t === 'Vector') {
    const xs = field(v, 'items', 'values', 'elements') ?? [];
    return '<' + xs.map(encodeValue).join(' ') + '>';
  }
  if (t === 'tuple' || t === 'Tuple') {
    const xs: any[] = field(v, 'items', 'values', 'elements') ?? [];
    if (xs.length < 2) throw new TypeError('tuple must contain at least two elements');
    let out = '(@p ' + encodeValue(xs[xs.length - 2]) + ' ' + encodeValue(xs[xs.length - 1]) + ')';
    for (let i = xs.length - 3; i >= 0; i--) out = '(@p ' + encodeValue(xs[i]) + ' ' + out + ')';
    return out;
  }
  if (t === 'list' || t === 'List' || t === 'improper-list') {
    const xs: any[] = field(v, 'items', 'values', 'elements', 'head') ?? [];
    let tail = field(v, 'tail');
    if (!Array.isArray(xs)) return encodeValue(v);
    const parts = xs.map(encodeValue);
    if (tail === undefined || tail === null) return '[' + parts.join(' ') + ']';
    // Flatten proper-list tails, as required by canonical encoding.
    if (tag(tail) === 'list' || tag(tail) === 'List' || Array.isArray(tail)) {
      const ti: any[] = Array.isArray(tail) ? tail : field(tail, 'items', 'values', 'elements') ?? [];
      return '[' + parts.concat(ti.map(encodeValue)).join(' ') + ']';
    }
    return '[' + parts.join(' ') + (parts.length ? ' | ' : '| ') + encodeValue(tail) + ']';
  }
  if (Array.isArray(v)) return '[' + v.map(encodeValue).join(' ') + ']';
  if (typeof v === 'string') return escapeString(v);
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  if (typeof v === 'number' || typeof v === 'bigint') return numberText(v);
  throw new TypeError('unsupported runtime value');
}

export function encode(value: any, _options?: EncodeOptions): string { return encodeValue(value); }
export const canonicalEncode = encode;
export default encode;

