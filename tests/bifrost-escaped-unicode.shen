\\ ASCII-only source exercises both SDN Unicode escape forms on every port.
(load "sdn.shen")

(define bifrost-unicode.quote
  S -> (cn (n->string 34) (cn S (n->string 34))))

(define bifrost-unicode.escape
  S -> (cn (n->string 92) S))

(define bifrost-unicode.run
  -> (let Scalar (sdn.decode
                    (bifrost-unicode.quote
                      (bifrost-unicode.escape "u{1F600}")))
          Pair (sdn.decode
                 (bifrost-unicode.quote
                   (cn (bifrost-unicode.escape "uD83D")
                       (bifrost-unicode.escape "uDE00"))))
          (if (sdn.equal? Scalar Pair)
              (do
                (output "Unicode escape forms agree~%")
                (output "SDN ESCAPED UNICODE PASS~%"))
              (simple-error "Unicode escape forms decoded differently"))))

(bifrost-unicode.run)
