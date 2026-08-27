\\ Conformance tests for sdn.shen. Run with ../shen-lua/bin/shen.

(set sdn-test.*passed* 0)

(define sdn-test.assert
  _ true -> (set sdn-test.*passed* (+ 1 (value sdn-test.*passed*)))
  Name false -> (simple-error (cn "SDN test failed: " Name)))

(define sdn-test.eq
  Name Expected Actual -> (sdn-test.assert Name (sdn.equal? Expected Actual)))

(define sdn-test.rejects
  Name Source -> (sdn-test.assert Name
    (trap-error (do (sdn.decode Source) false) (lambda E true))))

(define sdn-test.q
  S -> (cn (n->string 34) (cn S (n->string 34))))

(define sdn-test.bs
  -> (n->string 92))

(define sdn-test.valid-file
  Path -> (sdn-test.assert Path
    (trap-error (do (sdn.decode (read-file-as-string Path)) true) (lambda E false))))

(define sdn-test.invalid-file
  Path -> (sdn-test.assert Path
    (trap-error (do (sdn.decode (read-file-as-string Path)) false) (lambda E true))))

    (sdn-test.eq "symbol" name (sdn.decode "name"))
    (sdn-test.eq "uppercase symbol" X (sdn.decode "X"))
    (sdn-test.eq "string" "name" (sdn.decode (cn (n->string 34) (cn "name" (n->string 34)))))
    (sdn-test.eq "booleans" [true false] (sdn.decode "[true false]"))
    (sdn-test.eq "escaped symbol" (intern "<=") (sdn.decode (cn "#s" (sdn-test.q "<="))))
    (sdn-test.eq "integer" -42 (sdn.decode "-42"))
    (sdn-test.eq "largest policy integer" 9007199254740991 (sdn.decode "9007199254740991"))
    (sdn-test.eq "exact decimal" 0.125 (sdn.decode "0.125"))
    (sdn-test.eq "proper list" [one two three] (sdn.decode "[one two three]"))
    (sdn-test.eq "proper list tail normalization" [one two three]
      (sdn.decode "[one | [two three]]"))
    (sdn-test.eq "improper list" [one two | three] (sdn.decode "[one two | three]"))
    (sdn-test.eq "right associated tuple" (@p one (@p two three))
      (sdn.decode "(@p one two three)"))
    (sdn-test.eq "comments separate atoms" [one two]
      (sdn.decode (cn "[one" (cn (n->string 92) (cn (n->string 92)
        (cn "comment" (cn (n->string 10) "two]")))))))
    (sdn-test.eq "short escapes" (cn "A" (cn (n->string 10) "B"))
      (sdn.decode (sdn-test.q (cn "A" (cn (sdn-test.bs) "nB")))))
    (sdn-test.eq "scalar escape" (sdn.utf8-encode 128512)
      (sdn.decode (sdn-test.q (cn (sdn-test.bs) "u{1F600}"))))
    (sdn-test.eq "surrogate pair" (sdn.utf8-encode 128512)
      (sdn.decode (sdn-test.q (cn (sdn-test.bs) (cn "uD83D" (cn (sdn-test.bs) "uDE00"))))))
    (sdn-test.eq "canonical escaped newline" (sdn-test.q (cn "A" (cn (sdn-test.bs) "nB")))
      (sdn.canonical-encode (cn "A" (cn (n->string 10) "B"))))
    (sdn-test.eq "canonical whitespace" "[one two]" (sdn.canonical-encode (sdn.decode " [ one  two ] ")))
    (sdn-test.eq "canonical tuple" "(@p one (@p two three))"
      (sdn.canonical-encode (sdn.decode "(@p one two three)")))
    (sdn-test.eq "canonical symbol" (cn "#s" (sdn-test.q "<=")) (sdn.canonical-encode (intern "<=")))
    (sdn-test.eq "canonical improper list" (cn "[name | " (cn (sdn-test.q "Ada") "]"))
      (sdn.canonical-encode [name | "Ada"]))
    (sdn-test.eq "vector contents" 2 (<-vector (sdn.decode "<1 2 3>") 2))
    (sdn-test.eq "canonical vector" "<1 2 3>" (sdn.canonical-encode (sdn.decode "<1 2 3>")))
    (sdn-test.rejects "empty" "")
    (sdn-test.rejects "trailing data" "one two")
    (sdn-test.rejects "invalid number" "12abc")
    (sdn-test.rejects "leading zero" "01")
    (sdn-test.rejects "lossy decimal" "0.1")
    (sdn-test.rejects "unsafe integer" "9007199254740992")
    (sdn-test.assert "encoder rejects lossy host number"
      (trap-error (do (sdn.canonical-encode 0.1) false) (lambda E true)))
    (sdn-test.rejects "invalid escape" (sdn-test.q (cn (sdn-test.bs) "q")))
    (sdn-test.rejects "unpaired surrogate" (sdn-test.q (cn (sdn-test.bs) "uD800")))
    (sdn-test.rejects "invalid scalar" (sdn-test.q (cn (sdn-test.bs) "u{110000}")))
    (sdn-test.rejects "bad escaped symbol" (cn "#s" (sdn-test.q "bad|name")))
    (sdn-test.rejects "empty escaped symbol" (cn "#s" (sdn-test.q "")))
    (sdn-test.rejects "bad list tail" "[one | two three]")
    (sdn-test.rejects "short tuple" "(@p one)")
    (sdn-test.rejects "application" "(delete-everything)")

    (sdn-test.assert "depth override"
      (trap-error (do (sdn.decode-with "[[[x]]]" [[max-depth 2]]) false) (lambda E true)))
    (sdn-test.assert "collection override"
      (trap-error (do (sdn.decode-with "[1 2]" [[max-collection-length 1]]) false) (lambda E true)))
    (sdn-test.assert "string override"
      (trap-error (do (sdn.decode-with (sdn-test.q "abcd") [[max-string-bytes 3]]) false) (lambda E true)))

(map (fn sdn-test.valid-file)
  ["fixtures/valid/atoms.sdn"
   "fixtures/valid/collections.sdn"
   "fixtures/valid/large-integer.sdn"
   "fixtures/valid/nested.sdn"])

(map (fn sdn-test.invalid-file)
  ["fixtures/invalid/empty.sdn"
   "fixtures/invalid/invalid-escape.sdn"
   "fixtures/invalid/invalid-list-tail.sdn"
   "fixtures/invalid/invalid-number.sdn"
   "fixtures/invalid/invalid-tuple.sdn"
   "fixtures/invalid/trailing-data.sdn"
   "fixtures/invalid/unmatched-delimiter.sdn"
   "fixtures/invalid/unpaired-surrogate.sdn"
   "fixtures/invalid/unterminated-string.sdn"])

(output "sdn-tests: ~A passed~%" (value sdn-test.*passed*))
