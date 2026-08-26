/** Stable error categories defined by SDN section 11. */
export type ErrorCategory =
  | 'invalid-utf8'
  | 'unexpected-eof'
  | 'unexpected-token'
  | 'invalid-escape'
  | 'invalid-number'
  | 'invalid-symbol'
  | 'mismatched-delimiter'
  | 'invalid-list-tail'
  | 'invalid-tuple'
  | 'trailing-data'
  | 'resource-limit';

export interface SDNErrorOptions {
  /** Zero-based offset in the original UTF-8 input. */
  byteOffset?: number;
  /** Optional one-based source location, when known by the caller. */
  line?: number;
  column?: number;
  /** A short source excerpt or parser context. */
  context?: string;
  cause?: unknown;
}

/** Structured, machine-readable parser error. */
export class SDNError extends Error {
  readonly category: ErrorCategory;
  readonly byteOffset?: number;
  readonly offset?: number;
  readonly line?: number;
  readonly column?: number;
  readonly context?: string;
  /** Alias used by protocol layers that call the category a code. */
  readonly code: ErrorCategory;

  constructor(category: ErrorCategory, message: string, options: SDNErrorOptions | number = {}) {
    super(message);
    this.name = 'SDNError';
    this.category = category;
    const details: SDNErrorOptions = typeof options === 'number' ? { byteOffset: options } : options;
    this.code = category;
    this.byteOffset = details.byteOffset;
    // `offset` is retained as a convenient alias for parser consumers.
    this.offset = options.byteOffset;
    this.line = details.line;
    this.column = details.column;
    this.context = details.context;
    if (details.cause !== undefined) {
      (this as Error & { cause?: unknown }).cause = details.cause;
    }
    // Required when targeting ES5 and useful across transpilers.
    Object.setPrototypeOf(this, new.target.prototype);
  }

  toJSON(): Record<string, unknown> {
    const result: Record<string, unknown> = {
      name: this.name,
      category: this.category,
      message: this.message,
    };
    if (this.byteOffset !== undefined) result.byteOffset = this.byteOffset;
    if (this.line !== undefined) result.line = this.line;
    if (this.column !== undefined) result.column = this.column;
    if (this.context !== undefined) result.context = this.context;
    return result;
  }
}

/** Backwards-compatible descriptive alias. */
export const ParseError = SDNError;

/** Convenience factory for parsers that prefer not to invoke the class directly. */
export function sdnError(
  category: ErrorCategory,
  message: string,
  options?: SDNErrorOptions | number,
): SDNError {
  return new SDNError(category, message, options);
}

export function isSDNError(value: unknown): value is SDNError {
  return value instanceof SDNError;
}
