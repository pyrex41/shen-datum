# Shen Datum Notation

Shen Datum Notation (SDN) is a concise, inert, portable serialization format
for exchanging data between Shen implementations.

```shen
[request
  [version 1]
  [id "01JABC"]
  [operation search]
  [arguments ["lambda calculus" 20]]]
```

SDN preserves distinctions that JSON and JAMS lose, including symbols versus
strings, lists versus vectors, tuples, and improper lists. It resembles Shen
data syntax but never evaluates input.

The complete proposed specification is in [spec.md](spec.md).

## Status

This repository currently contains a draft specification. Implementations and
cross-port conformance fixtures are planned but not yet included.

## License

MIT
