/** Public SDN value model.
 *
 * Values are deliberately plain, immutable data.  In particular numbers do
 * not use JavaScript's Number: a decimal is stored as an integer coefficient
 * and a base-10 scale, so no precision is lost while decoding.
 */

export interface SymbolDatum { readonly kind: "symbol"; readonly name: string }
export interface StringDatum { readonly kind: "string"; readonly value: string }
export interface BooleanDatum { readonly kind: "boolean"; readonly value: boolean }

/** coefficient × 10^-scale (scale may be negative for exponent notation). */
export interface NumberDatum {
  readonly kind: "number";
  readonly coefficient: bigint;
  readonly scale: number;
}

export interface ListDatum { readonly kind: "list"; readonly items: readonly Datum[] }
export interface ImproperListDatum {
  readonly kind: "improper-list";
  readonly heads: readonly Datum[];
  readonly tail: Datum;
}
export interface VectorDatum { readonly kind: "vector"; readonly items: readonly Datum[] }
export interface TupleDatum { readonly kind: "tuple"; readonly items: readonly [Datum, Datum, ...Datum[]] }

export type Datum = SymbolDatum | StringDatum | BooleanDatum | NumberDatum |
  ListDatum | ImproperListDatum | VectorDatum | TupleDatum;
export type SdnValue = Datum;

const freeze = <T extends object>(x: T): T => Object.freeze(x);

export function symbol(name: string): SymbolDatum {
  if (typeof name !== "string") throw new TypeError("symbol name must be a string");
  return freeze({ kind: "symbol", name });
}

export const string = (value: string): StringDatum => freeze({ kind: "string", value });
export const boolean = (value: boolean): BooleanDatum => freeze({ kind: "boolean", value });

/** Construct an exact number. `scale` is the number of decimal places. */
export function number(coefficient: bigint | number | string, scale = 0): NumberDatum {
  if (!Number.isInteger(scale)) throw new RangeError("number scale must be an integer");
  let c: bigint;
  if (typeof coefficient === "bigint") c = coefficient;
  else if (typeof coefficient === "number") {
    if (!Number.isSafeInteger(coefficient)) throw new RangeError("number coefficient must be a safe integer; use bigint");
    c = BigInt(coefficient);
  } else c = BigInt(coefficient);
  return freeze({ kind: "number", coefficient: c, scale });
}

/** Parse an SDN number token without ever converting through a float. */
export function numberFromString(text: string): NumberDatum {
  if (!/^[+-]?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$/.test(text))
    throw new SyntaxError(`invalid SDN number: ${text}`);
  const m = /^([+-]?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$/.exec(text)!;
  const sign = m[1] === "-" ? -1n : 1n;
  const fraction = m[3] || "";
  let coefficient = sign * BigInt(m[2] + fraction);
  let scale = fraction.length - (m[4] ? Number(m[4]) : 0);
  if (coefficient === 0n) scale = 0;
  while (scale > 0 && coefficient % 10n === 0n) { coefficient /= 10n; scale--; }
  return number(coefficient, scale);
}

export const integer = (value: bigint | number | string): NumberDatum => number(value, 0);
export const decimal = numberFromString;
export const list = (items: readonly Datum[] = []): ListDatum => freeze({ kind: "list", items: Object.freeze([...items]) });
export const improperList = (heads: readonly Datum[], tail: Datum): ImproperListDatum => {
  if (!heads.length) throw new RangeError("improper list requires at least one head");
  return freeze({ kind: "improper-list", heads: Object.freeze([...heads]), tail });
};
export const vector = (items: readonly Datum[] = []): VectorDatum => freeze({ kind: "vector", items: Object.freeze([...items]) });
export function tuple(first: Datum, second: Datum, ...rest: Datum[]): TupleDatum {
  return freeze({ kind: "tuple", items: Object.freeze([first, second, ...rest]) as TupleDatum["items"] });
}

function numberEqual(a: NumberDatum, b: NumberDatum): boolean {
  if (a.coefficient === 0n && b.coefficient === 0n) return true;
  const scale = Math.max(a.scale, b.scale);
  return a.coefficient * 10n ** BigInt(scale - a.scale) === b.coefficient * 10n ** BigInt(scale - b.scale);
}

/** Structural SDN equality; improper lists ending in proper lists are flattened. */
export function equals(a: Datum, b: Datum): boolean {
  if (a.kind === "number" && b.kind === "number") return numberEqual(a, b);
  if (a.kind !== b.kind) {
    if ((a.kind === "list" || a.kind === "improper-list") && (b.kind === "list" || b.kind === "improper-list"))
      return equalsList(a, b);
    return false;
  }
  switch (a.kind) {
    case "symbol": return a.name === (b as SymbolDatum).name;
    case "string": return a.value === (b as StringDatum).value;
    case "boolean": return a.value === (b as BooleanDatum).value;
    case "list": case "vector": case "tuple": {
      const xs = a.items, ys = (b as typeof a).items;
      return xs.length === ys.length && xs.every((x, i) => equals(x, ys[i]));
    }
    case "improper-list": return equalsList(a, b as ImproperListDatum);
    default: return false;
  }
}

function flattenList(x: ListDatum | ImproperListDatum): Datum[] {
  if (x.kind === "list") return [...x.items];
  const result = [...x.heads];
  if (x.tail.kind === "list") result.push(...x.tail.items);
  else result.push(x.tail);
  return result;
}
function equalsList(a: ListDatum | ImproperListDatum, b: ListDatum | ImproperListDatum): boolean {
  const x = flattenList(a), y = flattenList(b);
  return x.length === y.length && x.every((v, i) => equals(v, y[i]));
}

export const equal = equals;

