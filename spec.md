# Shen Datum Notation (SDN)

## Status of this document

This document specifies Shen Datum Notation version 0.1. It is a draft intended
for implementation experiments and interoperability testing. Incompatible
changes may be made before version 1.0.

The key words **MUST**, **MUST NOT**, **REQUIRED**, **SHOULD**, **SHOULD NOT**,
and **MAY** are to be interpreted as normative requirements.

## 1. Purpose

Shen Datum Notation is a concise textual representation of portable Shen data.
It is intended for:

- communication between Shen ports, such as ShenScript and Shen-Go;
- request and response protocols;
- persisted application data;
- test fixtures and cross-port conformance tests;
- syntax trees, proof terms, and other symbolic data;
- data that will subsequently be checked by a Shen datatype.

SDN resembles Shen source notation so that decoded values are natural to
construct, inspect, and pattern-match in Shen. SDN is not a programming
language, a module format, or an evaluation protocol.

## 2. Design principles

1. **Inert.** Decoding data MUST NOT execute it.
2. **Lossless.** Distinct supported Shen values MUST remain distinct.
3. **Portable.** The data model MUST not depend on a port's host language.
4. **Small.** The grammar and required value model SHOULD remain compact.
5. **Readable.** Ordinary values SHOULD resemble Shen data notation.
6. **Extensible by convention.** Applications SHOULD use tagged data rather
   than adding syntax to the core format.

## 3. Data model

An SDN datum is exactly one of:

- symbol;
- string;
- boolean;
- number;
- proper list;
- improper list;
- vector;
- tuple.

The model deliberately excludes functions, closures, continuations, lazy
objects, streams, exceptions, host objects, mutable identity, shared-reference
identity, and cyclic values.

### 3.1 Symbols

A symbol is an internable Shen symbol name. Symbols and strings are distinct:

```shen
name     \\ symbol
"name"   \\ string
```

`true` and `false` are reserved boolean tokens and MUST NOT decode as symbols.
A token matching the number grammar MUST decode as a number rather than a
symbol.

Most symbols use bare Shen spelling. Symbols containing structural delimiters
use an escaped form whose contents follow the string escape rules:

```shen
#s"<"
#s">="
```

After unescaping, the contents MUST satisfy Shen's symbol-name rules. The
escaped form changes only notation; it still decodes as a symbol, not a string.

Uppercase symbols are permitted. An SDN decoder treats `X` as the symbol `X`;
it does not introduce a variable binding. A later consumer may interpret that
symbol as a logical variable in an explicitly selected context.

### 3.2 Strings

A string is a finite sequence of Unicode scalar values. The encoded document
MUST be UTF-8. Implementations claiming full conformance MUST preserve all
Unicode scalar values even if the host Shen port's ordinary string type cannot;
such a port MAY expose an explicit portable-string representation.

### 3.3 Booleans

The two boolean values are written `true` and `false`.

### 3.4 Numbers

An SDN number is a finite integer or finite decimal number. NaN, positive and
negative infinity, hexadecimal notation, ratios, and implementation-specific
numeric suffixes are not part of version 0.1.

Decoders MUST preserve integers exactly. Decoders SHOULD preserve decimal
values exactly. A decoder backed only by binary floating-point MUST reject a
value it cannot represent according to its documented numeric policy rather
than silently changing the value.

### 3.5 Lists

A proper list is an ordered sequence of zero or more data:

```shen
[]
[one two three]
[person [name "Ada"] [age 36]]
```

An improper list contains one or more heads followed by a non-list tail:

```shen
[name | "Ada"]
[one two | three]
```

The form `[one | [two three]]` is semantically equal to the proper list
`[one two three]`. Encoders MUST emit the proper-list form when the final tail
is a proper list.

### 3.6 Vectors

A vector is an ordered sequence distinct from a list:

```shen
<>
<1 2 3>
<name "Ada">
```

Decoding constructs a fresh standard Shen vector. Serialized data does not
preserve vector identity, mutation history, unused slots, or non-standard print
vectors.

### 3.7 Tuples

A tuple uses Shen's `@p` constructor notation:

```shen
(@p one two)
(@p one two three)
```

The polyadic form associates to the right. Therefore:

```shen
(@p one two three)
```

is semantically identical to:

```shen
(@p one (@p two three))
```

A tuple MUST contain at least two elements. Parentheses have no other meaning
in SDN. In particular, `(delete-everything)` is invalid data rather than a
function application.

## 4. Lexical grammar

The following grammar is normative EBNF. Concatenation is written by adjacency,
`|` denotes alternatives, `*` means zero or more, `+` means one or more, and
`?` means optional.

```ebnf
document      = spacing, datum, spacing, EOF ;

datum         = string
              | boolean
              | number
              | list
              | vector
              | tuple
              | escaped-symbol
              | bare-symbol ;

list          = "[", spacing, list-body?, spacing, "]" ;
list-body     = datum, (separator, datum)*,
                (separator, "|", separator, datum)? ;

vector        = "<", spacing,
                (datum, (separator, datum)*)?,
                spacing, ">" ;

tuple         = "(", spacing, "@p", separator,
                datum, separator, datum,
                (separator, datum)*,
                spacing, ")" ;

boolean       = "true" | "false" ;

number        = sign?, integer, fraction?, exponent? ;
sign          = "+" | "-" ;
integer       = "0" | nonzero-digit, digit* ;
fraction      = ".", digit+ ;
exponent      = ("e" | "E"), sign?, digit+ ;
digit         = "0" | nonzero-digit ;
nonzero-digit = "1" | "2" | "3" | "4" | "5"
              | "6" | "7" | "8" | "9" ;

escaped-symbol = "#s", string ;

bare-symbol   = bare-symbol-initial, bare-symbol-rest* ;
bare-symbol-rest = bare-symbol-initial | digit ;
bare-symbol-initial = ASCII-letter
               | "=" | "-" | "*" | "/" | "+" | "_"
               | "?" | "$" | "!" | "@" | "~" | "."
               | "&" | "%" | "'" | "#"
               | "`" | ";" | ":" ;

shen-symbol-name = shen-symbol-initial, shen-symbol-rest* ;
shen-symbol-rest = shen-symbol-initial | digit ;
shen-symbol-initial = bare-symbol-initial | "<" | ">" ;

string        = DQUOTE, string-item*, DQUOTE ;
string-item   = unescaped | escape ;
escape        = "\\", (DQUOTE | "\\" | "/" | "b" | "f"
                       | "n" | "r" | "t")
              | "\\u", hex, hex, hex, hex
              | "\\u{", hex+, "}" ;

spacing       = (whitespace | comment)* ;
separator     = (whitespace | comment)+ ;
whitespace    = SPACE | TAB | LF | CR ;
comment       = "\\\\", non-line-ending*, (LF | CR | EOF) ;
```

`ASCII-letter` is `A` through `Z` or `a` through `z`. `hex` is an ASCII
hexadecimal digit. `unescaped` is any Unicode scalar value except `"`, `\\`, or
a scalar in the range U+0000 through U+001F.

Tokenization MUST use maximal munch for atoms. Reserved booleans and valid
numbers are recognized before symbols. A token such as `12abc` is invalid: it
MUST NOT be split into the number `12` and symbol `abc` without a separator.

### 4.1 Structural delimiters and escaped symbols

`[`, `]`, `(`, `)`, `|`, `<`, and `>` are always structural delimiters. They
cannot occur in a bare symbol. This removes the ambiguity between a vector such
as `<a>` and a Shen symbol with the same spelling.

Shen symbol names containing a structural delimiter MUST use escaped-symbol
notation. Thus comparison operators are written as follows when used as data:

```shen
#s"<"
#s">"
#s"<="
#s">="
```

An encoder MUST use escaped-symbol notation when a symbol cannot be emitted as
a bare symbol or when its spelling would be recognized as a boolean or number.

### 4.2 Comments

Line comments begin with two backslashes and continue to the next line ending
or end of input, matching Shen's visual convention:

```shen
[person
  \\ identity
  [name "Ada"]]
```

Comments are discarded and have no decoded representation. A comment counts as
a separator even when it contains no whitespace.

## 5. String escapes

The following escapes are required:

| Escape | Value |
| --- | --- |
| `\"` | quotation mark |
| `\\` | reverse solidus |
| `\/` | solidus |
| `\b` | backspace |
| `\f` | form feed |
| `\n` | line feed |
| `\r` | carriage return |
| `\t` | horizontal tab |
| `\uXXXX` | one UTF-16 code unit, with valid surrogate pairing |
| `\u{X...}` | one Unicode scalar value |

Hexadecimal digits are case-insensitive. An unpaired UTF-16 surrogate, a value
greater than U+10FFFF, or a value in U+D800 through U+DFFF is invalid.

Encoders SHOULD use short escapes where available. They SHOULD emit printable
Unicode directly unless ASCII-only output was requested.

## 6. Whitespace and separation

Whitespace is insignificant except inside strings and where it separates two
tokens. Adjacent structural delimiters need no whitespace:

```shen
[[one][two]]
<[@p-value]>
```

Two atoms MUST be separated. Encoders SHOULD use one ASCII space for compact
output and indentation plus line feeds for human-readable output.

## 7. Semantics and equality

Decoding MUST construct data and MUST NOT invoke Shen evaluation, macro
expansion, function application, reader macros, datatype installation, symbol
lookup, or global assignment.

Two decoded SDN values are equal when:

- atoms have equal type and value;
- lists have equal proper/improper structure and recursively equal contents;
- vectors have recursively equal contents;
- tuples have recursively equal components.

Object identity is outside the data model. Decoding the same vector twice may
produce two different mutable vectors that are equal by contents.

## 8. Tagged data and records

Version 0.1 has no map or record primitive. Applications SHOULD represent
variants and records as tagged lists:

```shen
[person
  [name "Ada Lovelace"]
  [born 1815]
  [roles [mathematician writer]]]
```

This representation is portable and directly compatible with Shen pattern
matching and sequent-calculus datatype rules. Applications MUST specify whether
record field order matters and whether duplicate fields are permitted.

An association list is appropriate when arbitrary key types are needed:

```shen
[[name | "Ada"] [born | 1815]]
```

No universal interpretation of either convention is imposed by SDN.

## 9. Types and validation

Parsing and type validation are separate operations:

```text
UTF-8 bytes -> SDN datum -> application decoder or Shen type judgment
```

An SDN parser MUST NOT claim that successfully parsed data inhabits an
application type. Applications SHOULD validate untrusted data before use.

Shen's type system is Turing-equivalent; therefore validation of an arbitrary
user-supplied type theory may fail to terminate. SDN neither requires nor
attempts generic type inference, automatic codec derivation for every possible
datatype, or termination proofs.

Datatype definitions and proof rules MAY themselves be represented as tagged
SDN syntax trees. Installing or executing such a tree is code loading and MUST
be an explicit operation outside the decoder.

## 10. Protocol use

A protocol SHOULD use a versioned tagged envelope. Example request:

```shen
[request
  [protocol sdn-rpc]
  [version 1]
  [id "01JABC"]
  [operation search]
  [arguments ["lambda calculus" 20]]]
```

Successful response:

```shen
[response
  [protocol sdn-rpc]
  [version 1]
  [id "01JABC"]
  [ok [[title "The Book of Shen"] [score 0.94]]]]
```

Error response:

```shen
[response
  [protocol sdn-rpc]
  [version 1]
  [id "01JABC"]
  [error
    [code invalid-argument]
    [message "limit must be a positive integer"]]]
```

Transport framing is outside this specification. HTTP bodies, WebSocket text
messages, and length-prefixed byte streams are all possible transports. A
stream transport MUST define how one UTF-8 SDN document ends before another
begins.

The suggested media type is `application/vnd.shen-datum` until a registered
media type exists. The suggested file extension is `.sdn`.

## 11. Errors

A decoder MUST reject:

- empty input or more than one top-level datum;
- invalid UTF-8;
- malformed or unknown string escapes;
- invalid Unicode scalar values;
- invalid number syntax or unsupported numeric values;
- unmatched or incorrect delimiters;
- a list pipe without both a head and tail;
- more than one list pipe;
- a tuple with fewer than two elements;
- any parenthesized form other than `@p`;
- characters not admitted by the grammar.

Errors SHOULD report a stable category and the byte offset. Implementations MAY
also report line, column, context, and recovery information.

Suggested error categories are `invalid-utf8`, `unexpected-eof`,
`unexpected-token`, `invalid-escape`, `invalid-number`, `invalid-symbol`,
`mismatched-delimiter`, `invalid-list-tail`, `invalid-tuple`, `trailing-data`,
and `resource-limit`.

## 12. Security requirements

An implementation processing untrusted input:

- MUST NOT evaluate decoded data;
- MUST provide or document limits for input bytes, nesting depth, collection
  length, string length, symbol length, and numeric magnitude;
- MUST detect arithmetic overflow;
- SHOULD avoid recursion proportional to attacker-controlled nesting when the
  host stack is bounded;
- SHOULD allow callers to reject symbol interning or use temporary symbols, to
  prevent exhaustion of a global symbol table;
- MUST NOT fetch resources, resolve packages, invoke reader macros, or load type
  theories while parsing;
- SHOULD reject duplicate protocol fields when the enclosing application schema
  defines fields as unique.

## 13. Canonical encoding

Canonical SDN is useful for hashing, signatures, cache keys, and reproducible
artifacts. A canonical encoder MUST:

1. emit valid UTF-8 without a byte-order mark;
2. emit no comments or leading/trailing whitespace;
3. emit one ASCII space between adjacent elements;
4. emit no otherwise unnecessary whitespace next to delimiters;
5. use lowercase `true` and `false`;
6. encode zero as `0`, never `-0` or `+0`;
7. omit a leading plus sign;
8. emit integers without leading zeroes;
9. use lowercase `e` when exponent notation is necessary;
10. remove redundant fraction and exponent zeroes;
11. encode proper lists without `|`;
12. expand polyadic tuples to their semantic right-associated form;
13. escape quotation mark, reverse solidus, and U+0000 through U+001F, using
    short escapes where defined;
14. emit all other Unicode scalar values directly.
15. emit a symbol bare exactly when it satisfies `bare-symbol` and is not a
    reserved boolean or number; otherwise use escaped-symbol notation.

Canonicalization preserves SDN value equality, not source spelling. Version
0.1 does not define sorting for application-level record fields.

Examples:

```text
[one two three]
<1 2 3>
(@p one (@p two three))
[name | "Ada"]
```

## 14. Streaming API recommendations

Although transport framing is out of scope, parser APIs SHOULD support:

- decoding one complete document from bytes or text;
- decoding one datum and returning the unconsumed input;
- incremental decoding with explicit end-of-input;
- encoding to a byte or character sink;
- caller-configurable resource limits;
- preserving a structured error category and byte offset.

Implementations MUST distinguish incomplete input from definitively invalid
input when used incrementally.

## 15. Conformance

A conforming decoder MUST implement every version 0.1 datum and rejection rule.
A conforming encoder MUST emit input accepted by a conforming decoder and MUST
reject unsupported runtime values rather than silently coercing them.

A canonical encoder additionally MUST follow section 13.

The eventual conformance suite SHOULD contain:

- source files paired with a language-neutral expected syntax tree;
- invalid files paired with expected error categories;
- canonical input/output pairs;
- deeply nested and resource-limit cases;
- Unicode and numeric boundary cases;
- cross-port round trips among at least two independent implementations.

## 16. Versioning and extension policy

The grammar has no implicit extension mechanism. Unknown syntax MUST be
rejected. New semantic conventions SHOULD be expressed as tagged lists:

```shen
[uuid "67e55044-10b1-426f-9247-bb680e5fe0c8"]
[timestamp "2026-08-26T18:30:00Z"]
[decimal "1234567890.123456789"]
```

An incompatible grammar or data-model change requires a new SDN version.
Protocols embedding SDN SHOULD carry their own version independently of the SDN
syntax version.

## Appendix A: Examples

### A.1 Atomic values

```shen
symbol
"symbol"
true
false
0
-42
3.14159
6.022e23
```

### A.2 Collections

```shen
[]
[a b c]
[a b | c]
<>
<a b c>
(@p a b)
(@p a (@p b c))
```

### A.3 Typed symbolic data

```shen
[add
  [integer 9]
  [multiply [integer 7] [integer 3]]]
```

### A.4 Browser/backend exchange

```shen
[event
  [version 1]
  [kind user-created]
  [payload
    [user
      [id "usr_123"]
      [name "Ada"]
      [roles [admin author]]]]]
```

## Appendix B: Rationale

### Why not JSON?

JSON is an excellent transport when its data model is sufficient. It does not
natively distinguish Shen symbols from strings, lists from vectors, or tuples
from arrays, and it cannot directly represent improper lists. Tagged JSON can
represent these values but is less natural for Shen code and pattern matching.

### Why not JAMS?

JAMS provides attractive whitespace-oriented syntax, but all leaves are strings
and its collections correspond to arrays and string-keyed objects. SDN retains
the concise whitespace style while adopting Shen's atom and sequence
distinctions.

### Why no map primitive?

Shen's portable core has no single obvious immutable map value shared by every
port. Tagged lists and association lists are sufficient to build records and
maps without imposing a host-specific representation. A later version may add
a map only if cross-port implementation experience demonstrates a common need
and semantics.

### Why is `eval` forbidden?

Serialization is a trust boundary. Treating received data as Shen source would
turn decoding into arbitrary code execution and would make protocol behavior
depend on macros, packages, globals, and the selected port. An explicit
application operation may interpret a decoded AST after authorization, but
that operation is not parsing.
