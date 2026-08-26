/** Limits applied while decoding untrusted SDN input. Values are inclusive. */
export interface ResourceLimits {
  /** Maximum encoded input size, in UTF-8 bytes. */
  maxInputBytes: number;
  /** Maximum nesting depth of lists, vectors and tuples. */
  maxDepth: number;
  /** Maximum number of elements in any collection. */
  maxCollectionLength: number;
  /** Maximum Unicode scalar values in a string. */
  maxStringLength: number;
  /** Maximum Unicode scalar values in a symbol name. */
  maxSymbolLength: number;
  /** Maximum decimal digits in a numeric token (excluding sign, dot, exponent). */
  maxNumericDigits: number;
  /** Maximum absolute decimal exponent/magnitude accepted by a parser. */
  maxNumericMagnitude: number;
}

/** Conservative defaults suitable for network-facing decoders. */
export const DEFAULT_LIMITS: Readonly<ResourceLimits> = Object.freeze({
  maxInputBytes: 16 * 1024 * 1024,
  maxDepth: 256,
  maxCollectionLength: 1_000_000,
  maxStringLength: 1_000_000,
  maxSymbolLength: 64 * 1024,
  maxNumericDigits: 1_000,
  maxNumericMagnitude: 1_000_000,
});

/** Explicitly named alias for consumers that prefer the longer form. */
export const DEFAULT_RESOURCE_LIMITS = DEFAULT_LIMITS;

export type Limits = Partial<ResourceLimits>;

/** Merge caller settings with defaults and reject unusable values early. */
export function normalizeLimits(overrides?: Limits): ResourceLimits {
  const result = { ...DEFAULT_LIMITS, ...(overrides ?? {}) } as ResourceLimits;
  for (const key of Object.keys(DEFAULT_LIMITS) as Array<keyof ResourceLimits>) {
    const value = result[key];
    if (!Number.isSafeInteger(value) || value < 0) {
      throw new RangeError(`SDN limit ${key} must be a non-negative safe integer`);
    }
  }
  return result;
}

/** UTF-8 byte length without throwing on malformed text (TextEncoder replaces it). */
export function utf8ByteLength(input: string): number {
  if (typeof TextEncoder !== 'undefined') return new TextEncoder().encode(input).byteLength;
  // Small dependency-free fallback for runtimes without TextEncoder.
  let bytes = 0;
  for (let i = 0; i < input.length; i++) {
    const cp = input.codePointAt(i)!;
    if (cp > 0xffff) i++;
    bytes += cp <= 0x7f ? 1 : cp <= 0x7ff ? 2 : cp <= 0xffff ? 3 : 4;
  }
  return bytes;
}

export function assertInputBytes(length: number, limits: ResourceLimits): void {
  if (length > limits.maxInputBytes) throw new RangeError('SDN resource-limit: input exceeds maxInputBytes');
}

export function assertDepth(depth: number, limits: ResourceLimits): void {
  if (depth > limits.maxDepth) throw new RangeError('SDN resource-limit: nesting depth exceeded');
}
