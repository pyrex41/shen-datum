# Shen Datum Notation (SDN)

Shen Datum Notation is a small, inert, UTF-8 serialization format for portable
Shen data. The normative version 0.1 draft is in [spec.md](spec.md).

This repository contains a portable Shen implementation tested with Shen 42
and the adjacent
adjacent `shen-cl`, `shen-lua`, `shen-erl`, `shen-go`, and `shen-rust`
checkouts. Decoding constructs ordinary Shen values
and never evaluates input, expands macros, invokes the Shen source reader on
untrusted forms, loads packages, or installs datatypes.

## Run with shen-lua

From this repository:

```sh
../shen-lua/bin/shen --hush-load sdn.shen tests/sdn-tests.shen
```

Load `sdn.shen` in an application and call:

```shen
(sdn.decode "[person [name \"Ada\"] [age 36]]")
(sdn.canonical-encode [person [name "Ada"] [age 36]])
```

The public functions are:

- `sdn.decode : string --> A` — decode one complete SDN document;
- `sdn.decode-with : string --> (list (list A)) --> B` — decode with resource
  limit overrides;
- `sdn.encode` and `sdn.canonical-encode` — emit canonical SDN.
- `sdn.equal?` — structural SDN equality independent of a port's vector or
  tuple identity semantics.

Decoded symbols are interned Shen symbols. Strings, booleans, proper and
improper lists, vectors, and tuples become their corresponding standard Shen
values. Polyadic tuples are normalized to right-associated `@p` values, and a
list whose pipe tail is proper is normalized to a proper list.

## Limits and errors

`sdn.decode-with` accepts entries such as:

```shen
[[max-input-bytes 1048576]
 [max-depth 64]
 [max-collection-length 10000]
 [max-string-bytes 65536]
 [max-symbol-bytes 1024]
 [max-number-digits 16]]
```

Defaults are defined at the top of `sdn.shen`. Errors have the stable textual
form `sdn:<category>:<byte-offset>: <message>`, using the categories suggested
by section 11 of the specification.

`shen-lua` uses IEEE-754 binary64 numbers. To honor SDN's losslessness rule,
this implementation accepts integers only through 2^53−1 in magnitude and
accepts a decimal fraction only when its decimal coefficient is within that
range and its reduced denominator is a power of two. Thus `0.125` is accepted,
while `0.1`, `6.02e23`, and oversized integers are rejected as
`invalid-number` instead of being silently rounded. This is the documented
numeric policy permitted for a binary-floating-point-backed decoder; it means
this port does not claim full numeric conformance for every SDN number.

The implementation validates UTF-8 byte sequences itself, including overlong
forms, surrogate encodings, and values beyond U+10FFFF. Both `\uXXXX` surrogate
pairs and `\u{...}` scalar escapes are supported.

## Port status

The portable 54-assertion core suite passes on the explicitly verified Shen 42
worktrees for `shen-lua` and `shen-erl`; the raw UTF-8 fixture also passes on
each of those lanes. The root `shen-cl`, `shen-go`, and
`shen-julia` checkouts currently report 41.2 and are excluded from Shen 42
claims. `ShenScript-shen42` is a rejected community-kernel lineage and is also
excluded until rebuilt from the canonical Tarver mirror.

The original `shen-rust` `tlstr` defect discovered by this suite was fixed in
[shen-rust PR #19](https://github.com/pyrex41/shen-rust/pull/19). Its corrected
string primitives operate on Unicode scalars, while this SDN parser currently
walks encoded bytes; adapting the parser to both string models remains necessary
before the raw-Unicode fixture passes there. ASCII documents and escaped Unicode
are covered by the passing core suite.
Run the suites with each port's standard launcher protocol, for example:

```sh
../shen-lua-shen42/bin/shen --hush-load sdn.shen tests/sdn-tests.shen
../shen-erl/bin/shen-erl eval -e '(load "sdn.shen")' -e '(load "tests/sdn-tests.shen")'
```

## Bifrost matrix

[`bifrost.suite.json`](bifrost.suite.json) makes the conformance suite available
as a Bifrost add-on. It runs the core assertions, canonical examples, and
escaped-Unicode equivalence on every selected port:

Nix is an optional convenience here: SDN and every Shen port still run through
their ordinary launchers without it. The command below asks Bifrost to compose
the independently pinned port environments for a reproducible full matrix.

```sh
nix run ../bifrost#env -- all -- \
  python3 ../bifrost/bifrost.py \
    --suite ./bifrost.suite.json \
    --heavy
```

The Bifrost matrix is not a Shen 42 gate until its adapters are pinned to the
corresponding Shen 42 worktrees. The checked-in root matrix currently mixes
41.2 and 42 runtimes (and its Truffle launcher emits no required pass markers),
so use the explicit worktree commands above for Shen 42 verification. The
cases use pass markers because some launchers print
port-specific `load` diagnostics; the programs themselves assert the expected
canonical values before emitting those markers.

## Canonical encoding

The encoder emits no comments or outer whitespace, uses one space between
elements, escapes strings and symbols as required, flattens proper list tails,
and expands polyadic tuples to their semantic right-associated representation.
Unsupported Shen runtime values are rejected.

## Fixtures

The [`fixtures/`](fixtures/) directory contains language-neutral valid,
invalid, and canonical examples. The Shen test suite additionally exercises
the port-specific lossless numeric policy and resource limits.

## License

MIT
