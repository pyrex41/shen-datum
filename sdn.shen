\\ Shen Datum Notation 0.1 for Shen.
\\ The decoder is inert: it never invokes eval, macros, or the Shen reader on
\\ anything except an atom already proven to satisfy SDN's number grammar.

(set sdn.*max-input-bytes* 16777216)
(set sdn.*max-depth* 256)
(set sdn.*max-collection-length* 1000000)
(set sdn.*max-string-bytes* 1000000)
(set sdn.*max-symbol-bytes* 65536)
(set sdn.*max-number-digits* 16)

(define sdn.error
  Category Offset Message ->
    (simple-error (cn "sdn:" (cn (str Category)
      (cn ":" (cn (str Offset) (cn ": " Message)))))))

(define sdn.byte
  S -> (string->n (hdstr S)))

(define sdn.drop
  "" -> ""
  S -> (tlstr S))

(define sdn.starts2?
  S A B -> (and (not (= S ""))
            (and (= (sdn.byte S) A)
              (let T (tlstr S)
                (and (not (= T "")) (= (sdn.byte T) B))))))

(define sdn.ws?
  B -> (element? B [9 10 13 32]))

(define sdn.delimiter?
  B -> (element? B [40 41 60 62 91 93 124]))

(define sdn.hex-value
  B -> (- B 48) where (and (>= B 48) (<= B 57))
  B -> (+ 10 (- B 65)) where (and (>= B 65) (<= B 70))
  B -> (+ 10 (- B 97)) where (and (>= B 97) (<= B 102))
  _ -> -1)

(define sdn.ascii-letter?
  B -> (or (and (>= B 65) (<= B 90))
           (and (>= B 97) (<= B 122))))

(define sdn.digit?
  B -> (and (>= B 48) (<= B 57)))

(define sdn.bare-initial?
  B -> (or (sdn.ascii-letter? B)
        (element? B [33 35 36 37 38 39 42 43 45 46 47 58 59 61 63 64 95 96 126])))

(define sdn.shen-symbol-byte?
  B -> (or (sdn.bare-initial? B) (element? B [60 62])))

(define sdn.pow
  _ 0 -> 1
  N P -> (* N (sdn.pow N (- P 1))) where (> P 0))

(define sdn.abs
  N -> (- 0 N) where (< N 0)
  N -> N)

\\ Positive integer quotient and remainder, kept in Shen rather than relying
\\ on optional host maths-library functions such as floor or mod.
(define sdn.quotient
  N D -> (if (< N D) 0 (sdn.quotient-grow N D D 1)))

(define sdn.quotient-grow
  N D Multiple Units ->
    (if (<= (+ Multiple Multiple) N)
        (sdn.quotient-grow N D (+ Multiple Multiple) (+ Units Units))
        (+ Units (sdn.quotient (- N Multiple) D))))

(define sdn.remainder
  N D -> (- N (* (sdn.quotient N D) D)))

\\ Return [remaining-string byte-offset saw-separator].
(define sdn.spacing
  "" O -> ["" O false]
  S O -> (sdn.spacing-seen (tlstr S) (+ O 1)) where (sdn.ws? (sdn.byte S))
  S O -> (sdn.comment (tlstr (tlstr S)) (+ O 2)) where (sdn.starts2? S 92 92)
  S O -> [S O false])

(define sdn.spacing-seen
  S O -> (let R (sdn.spacing S O) [(hd R) (hd (tl R)) true]))

(define sdn.comment
  "" O -> ["" O true]
  S O -> (sdn.spacing-seen (tlstr S) (+ O 1)) where (element? (sdn.byte S) [10 13])
  S O -> (sdn.comment (tlstr S) (+ O 1)))

(define sdn.require-separator
  S O -> (let R (sdn.spacing S O)
           (if (or (hd (tl (tl R))) (sdn.structural-boundary? S (hd R)))
               R
               (sdn.error unexpected-token O "expected separator"))))

(define sdn.structural-boundary?
  Before After -> (and (not (= Before ""))
                    (and (not (= After ""))
                      (or (element? (sdn.byte Before) [40 60 91])
                          (element? (sdn.byte After) [41 62 93])))))

(define sdn.decode
  Text -> (sdn.decode-with Text []))

(define sdn.decode-with
  Text _ -> (sdn.error invalid-utf8 0 "input must be a string") where (not (string? Text))
  Text Limits ->
    (if (> (sdn.byte-length Text) (sdn.limit max-input-bytes Limits (value sdn.*max-input-bytes*)))
        (sdn.error resource-limit 0 "input exceeds max-input-bytes")
        (let U (sdn.validate-utf8 Text 0)
          (let S (sdn.spacing Text 0)
            (if (= (hd S) "")
                (sdn.error unexpected-eof (hd (tl S)) "empty input")
                (let R (sdn.datum (hd S) (hd (tl S)) 0 Limits)
                  (let Z (sdn.spacing (hd (tl R)) (hd (tl (tl R))))
                    (if (= (hd Z) "")
                        (hd R)
                        (sdn.error trailing-data (hd (tl Z)) "more than one top-level datum")))))))))

(define sdn.limit
  _ [] Default -> Default
  Key [[Key Value] | _] _ -> Value
  Key [_ | Rest] Default -> (sdn.limit Key Rest Default))

(define sdn.byte-length
  "" -> 0
  S -> (+ 1 (sdn.byte-length (tlstr S))))

\\ Strict UTF-8 validation.  Shen-lua exposes one encoded byte per hdstr.
(define sdn.validate-utf8
  "" _ -> true
  S O -> (let B (sdn.byte S)
    (cond
      ((< B 128) (sdn.validate-utf8 (tlstr S) (+ O 1)))
      ((and (>= B 194) (<= B 223)) (sdn.utf8-tail S O 1 128 191))
      ((= B 224) (sdn.utf8-tail S O 2 160 191))
      ((and (>= B 225) (<= B 236)) (sdn.utf8-tail S O 2 128 191))
      ((= B 237) (sdn.utf8-tail S O 2 128 159))
      ((and (>= B 238) (<= B 239)) (sdn.utf8-tail S O 2 128 191))
      ((= B 240) (sdn.utf8-tail S O 3 144 191))
      ((and (>= B 241) (<= B 243)) (sdn.utf8-tail S O 3 128 191))
      ((= B 244) (sdn.utf8-tail S O 3 128 143))
      (true (sdn.error invalid-utf8 O "invalid UTF-8 lead byte")))))

(define sdn.utf8-tail
  S O N Low High ->
    (let T (tlstr S)
      (if (= T "")
          (sdn.error invalid-utf8 (+ O 1) "truncated UTF-8 sequence")
          (let B (sdn.byte T)
            (if (and (>= B Low) (<= B High))
                (sdn.utf8-rest (tlstr T) (+ O 2) (- N 1))
                (sdn.error invalid-utf8 (+ O 1) "invalid UTF-8 continuation byte"))))))

(define sdn.utf8-rest
  S O 0 -> (sdn.validate-utf8 S O)
  "" O _ -> (sdn.error invalid-utf8 O "truncated UTF-8 sequence")
  S O N -> (let B (sdn.byte S)
             (if (and (>= B 128) (<= B 191))
                 (sdn.utf8-rest (tlstr S) (+ O 1) (- N 1))
                 (sdn.error invalid-utf8 O "invalid UTF-8 continuation byte"))))

\\ A parse result is [value remaining-string next-byte-offset].
(define sdn.datum
  "" O _ _ -> (sdn.error unexpected-eof O "expected datum")
  S O D L -> (sdn.string (tlstr S) (+ O 1) "" 0 L) where (= (sdn.byte S) 34)
  S O D L -> (sdn.list (tlstr S) (+ O 1) (+ D 1) L []) where (= (sdn.byte S) 91)
  S O D L -> (sdn.vector (tlstr S) (+ O 1) (+ D 1) L []) where (= (sdn.byte S) 60)
  S O D L -> (sdn.tuple (tlstr S) (+ O 1) (+ D 1) L) where (= (sdn.byte S) 40)
  S O D L -> (sdn.escaped-symbol (tlstr (tlstr (tlstr S))) (+ O 3) L)
    where (sdn.starts2? S 35 115)
  S O _ L -> (sdn.atom S O L))

(define sdn.check-depth
  D L O -> (if (> D (sdn.limit max-depth L (value sdn.*max-depth*)))
               (sdn.error resource-limit O "nesting depth exceeded") true))

(define sdn.string
  "" O _ _ _ -> (sdn.error unexpected-eof O "unterminated string")
  S O Acc N _ -> [Acc (tlstr S) (+ O 1)] where (= (sdn.byte S) 34)
  S O Acc N L -> (sdn.escape (tlstr S) (+ O 1) Acc N L) where (= (sdn.byte S) 92)
  S O _ _ _ -> (sdn.error invalid-escape O "unescaped control character") where (< (sdn.byte S) 32)
  S O Acc N L ->
    (if (>= N (sdn.limit max-string-bytes L (value sdn.*max-string-bytes*)))
        (sdn.error resource-limit O "string length exceeded")
        (sdn.string (tlstr S) (+ O 1) (cn Acc (hdstr S)) (+ N 1) L)))

(define sdn.escape
  "" O _ _ _ -> (sdn.error unexpected-eof O "incomplete escape")
  S O Acc N L -> (sdn.string (tlstr S) (+ O 1) (cn Acc (n->string 34)) (+ N 1) L) where (= (sdn.byte S) 34)
  S O Acc N L -> (sdn.string (tlstr S) (+ O 1) (cn Acc (n->string 92)) (+ N 1) L) where (= (sdn.byte S) 92)
  S O Acc N L -> (sdn.string (tlstr S) (+ O 1) (cn Acc (n->string 47)) (+ N 1) L) where (= (sdn.byte S) 47)
  S O Acc N L -> (sdn.string (tlstr S) (+ O 1) (cn Acc (n->string 8)) (+ N 1) L) where (= (sdn.byte S) 98)
  S O Acc N L -> (sdn.string (tlstr S) (+ O 1) (cn Acc (n->string 12)) (+ N 1) L) where (= (sdn.byte S) 102)
  S O Acc N L -> (sdn.string (tlstr S) (+ O 1) (cn Acc (n->string 10)) (+ N 1) L) where (= (sdn.byte S) 110)
  S O Acc N L -> (sdn.string (tlstr S) (+ O 1) (cn Acc (n->string 13)) (+ N 1) L) where (= (sdn.byte S) 114)
  S O Acc N L -> (sdn.string (tlstr S) (+ O 1) (cn Acc (n->string 9)) (+ N 1) L) where (= (sdn.byte S) 116)
  S O Acc N L -> (sdn.unicode-escape (tlstr S) (+ O 1) Acc N L) where (= (sdn.byte S) 117)
  _ O _ _ _ -> (sdn.error invalid-escape O "unknown escape"))

(define sdn.unicode-escape
  "" O _ _ _ -> (sdn.error unexpected-eof O "incomplete Unicode escape")
  S O Acc N L -> (sdn.hex-braced (tlstr S) (+ O 1) Acc N L 0 0) where (= (sdn.byte S) 123)
  S O Acc N L -> (sdn.hex-four S O Acc N L 0 0))

(define sdn.hex-four
  S O Acc N L Value 4 -> (sdn.finish-hex4 Value S O Acc N L)
  "" O _ _ _ _ _ -> (sdn.error unexpected-eof O "incomplete Unicode escape")
  S O Acc N L Value Count ->
    (let H (sdn.hex-value (sdn.byte S))
      (if (= H -1) (sdn.error invalid-escape O "invalid hex digit")
          (sdn.hex-four (tlstr S) (+ O 1) Acc N L (+ (* Value 16) H) (+ Count 1)))))

(define sdn.finish-hex4
  V S O Acc N L -> (sdn.low-surrogate S O Acc N L V 0 0)
    where (and (>= V 55296) (<= V 56319))
  V _ O _ _ _ -> (sdn.error invalid-escape O "unpaired low surrogate")
    where (and (>= V 56320) (<= V 57343))
  V S O Acc N L -> (sdn.add-scalar V S O Acc N L))

(define sdn.low-surrogate
  S O _ _ _ _ _ 0 -> (sdn.error invalid-escape O "unpaired high surrogate")
    where (not (sdn.starts2? S 92 117))
  S O Acc N L High _ 0 -> (sdn.low-surrogate (tlstr (tlstr S)) (+ O 2) Acc N L High 0 1)
  "" O _ _ _ _ _ _ -> (sdn.error unexpected-eof O "incomplete low surrogate")
  S O Acc N L High Value Count ->
    (let H (sdn.hex-value (sdn.byte S))
      (if (= H -1) (sdn.error invalid-escape O "invalid low surrogate")
        (let V (+ (* Value 16) H)
          (if (= Count 4)
              (if (and (>= V 56320) (<= V 57343))
                  (sdn.add-scalar (+ 65536 (+ (* (- High 55296) 1024) (- V 56320)))
                    (tlstr S) (+ O 1) Acc N L)
                  (sdn.error invalid-escape O "invalid low surrogate"))
              (sdn.low-surrogate (tlstr S) (+ O 1) Acc N L High V (+ Count 1)))))))

(define sdn.hex-braced
  "" O _ _ _ _ _ -> (sdn.error unexpected-eof O "incomplete Unicode escape")
  S O Acc N L Value Count -> (sdn.add-scalar Value (tlstr S) (+ O 1) Acc N L)
    where (and (= (sdn.byte S) 125) (> Count 0))
  S O _ _ _ _ 0 -> (sdn.error invalid-escape O "empty Unicode escape") where (= (sdn.byte S) 125)
  S O Acc N L Value Count ->
    (let H (sdn.hex-value (sdn.byte S))
      (if (= H -1) (sdn.error invalid-escape O "invalid hex digit")
          (if (>= Count 6) (sdn.error invalid-escape O "Unicode scalar is too large")
              (sdn.hex-braced (tlstr S) (+ O 1) Acc N L (+ (* Value 16) H) (+ Count 1))))))

(define sdn.add-scalar
  V _ O _ _ _ -> (sdn.error invalid-escape O "invalid Unicode scalar value")
    where (or (> V 1114111) (and (>= V 55296) (<= V 57343)))
  V S O Acc N L -> (sdn.string S O (cn Acc (sdn.utf8-encode V)) (+ N 1) L))

(define sdn.utf8-encode
  V -> (n->string V) where (< V 128)
  V -> (cn (n->string (+ 192 (sdn.quotient V 64)))
           (n->string (+ 128 (sdn.remainder V 64)))) where (< V 2048)
  V -> (cn (n->string (+ 224 (sdn.quotient V 4096)))
        (cn (n->string (+ 128 (sdn.remainder (sdn.quotient V 64) 64)))
            (n->string (+ 128 (sdn.remainder V 64))))) where (< V 65536)
  V -> (cn (n->string (+ 240 (sdn.quotient V 262144)))
        (cn (n->string (+ 128 (sdn.remainder (sdn.quotient V 4096) 64)))
         (cn (n->string (+ 128 (sdn.remainder (sdn.quotient V 64) 64)))
             (n->string (+ 128 (sdn.remainder V 64)))))))

(define sdn.escaped-symbol
  S O L -> (let R (sdn.string S O "" 0 L)
    (let Name (hd R)
      (if (or (= Name "") (not (sdn.shen-symbol-name? Name true)))
          (sdn.error invalid-symbol O "escaped symbol is not a Shen symbol name")
          (if (> (sdn.byte-length Name) (sdn.limit max-symbol-bytes L (value sdn.*max-symbol-bytes*)))
              (sdn.error resource-limit O "symbol length exceeded")
              [(intern Name) (hd (tl R)) (hd (tl (tl R)))])))))

(define sdn.shen-symbol-name?
  "" First -> (not First)
  S true -> (and (sdn.shen-symbol-byte? (sdn.byte S))
                 (sdn.shen-symbol-name? (tlstr S) false))
  S false -> (and (or (sdn.shen-symbol-byte? (sdn.byte S)) (sdn.digit? (sdn.byte S)))
                  (sdn.shen-symbol-name? (tlstr S) false)))

(define sdn.atom
  S O L -> (let R (sdn.atom-token S O "")
    (let Tok (hd R)
      (if (= Tok "") (sdn.error unexpected-token O "character is not admitted by SDN")
        (let V (sdn.classify-atom Tok O L)
          [V (hd (tl R)) (hd (tl (tl R)))])))))

(define sdn.atom-token
  "" O Acc -> [Acc "" O]
  S O Acc -> [Acc S O] where (or (sdn.ws? (sdn.byte S)) (sdn.delimiter? (sdn.byte S))
                                  (sdn.starts2? S 92 92))
  S O Acc -> (sdn.atom-token (tlstr S) (+ O 1) (cn Acc (hdstr S))))

(define sdn.classify-atom
  "true" _ _ -> true
  "false" _ _ -> false
  Tok O L -> (sdn.parse-number Tok O L) where (sdn.number-leading? Tok)
  Tok O L -> (if (not (sdn.bare-symbol? Tok true))
                 (sdn.error invalid-symbol O "invalid bare symbol")
                 (if (> (sdn.byte-length Tok) (sdn.limit max-symbol-bytes L (value sdn.*max-symbol-bytes*)))
                     (sdn.error resource-limit O "symbol length exceeded")
                     (intern Tok))))

(define sdn.number-leading?
  "" -> false
  S -> (or (sdn.digit? (sdn.byte S))
           (let T (tlstr S)
             (and (element? (sdn.byte S) [43 45])
                  (not (= T ""))
                  (sdn.digit? (sdn.byte T))))))

(define sdn.bare-symbol?
  "" _ -> false
  S true -> (and (sdn.bare-initial? (sdn.byte S))
                 (if (= (tlstr S) "") true (sdn.bare-symbol? (tlstr S) false)))
  S false -> (and (or (sdn.bare-initial? (sdn.byte S)) (sdn.digit? (sdn.byte S)))
                  (if (= (tlstr S) "") true (sdn.bare-symbol? (tlstr S) false))))

\\ Validate the normative grammar, then convert only the exactly representable
\\ subset of IEEE-754 binary64.  Integers are limited to 2^53-1.  A decimal
\\ fraction is exact only after all factors of five have cancelled.
(define sdn.parse-number
  Tok O L -> (let P (sdn.number-parts Tok O)
    (let Digits (hd P)
      (if (> (length Digits) (sdn.limit max-number-digits L (value sdn.*max-number-digits*)))
          (sdn.error resource-limit O "numeric digit limit exceeded")
          (let Coeff (sdn.digits-number Digits 0)
            (let Signed (if (= (hd (tl P)) -1) (- 0 Coeff) Coeff)
              (let Scale (hd (tl (tl P)))
                (sdn.lossless-number Signed Scale Tok O))))))))

\\ number-parts returns [all-digits sign decimal-scale].
(define sdn.number-parts
  Tok O -> (sdn.number-sign Tok O 1))

(define sdn.number-sign
  S O _ -> (sdn.error invalid-number O "incomplete number") where (= S "")
  S O _ -> (sdn.number-integer (tlstr S) (+ O 1) -1 [] 0 false) where (= (sdn.byte S) 45)
  S O _ -> (sdn.number-integer (tlstr S) (+ O 1) 1 [] 0 false) where (= (sdn.byte S) 43)
  S O Sign -> (sdn.number-integer S O Sign [] 0 false))

(define sdn.number-integer
  "" O Sign Digits Scale Seen -> [Digits Sign Scale] where Seen
  "" O _ _ _ _ -> (sdn.error invalid-number O "missing integer digits")
  S O Sign [] Scale false ->
    (if (= (sdn.byte S) 48)
        (sdn.number-after-integer (tlstr S) (+ O 1) Sign [0] Scale)
        (if (and (>= (sdn.byte S) 49) (<= (sdn.byte S) 57))
            (sdn.number-integer (tlstr S) (+ O 1) Sign [(- (sdn.byte S) 48)] Scale true)
            (sdn.error invalid-number O "missing integer digits")))
  S O Sign Digits Scale true ->
    (if (sdn.digit? (sdn.byte S))
        (sdn.number-integer (tlstr S) (+ O 1) Sign (append Digits [(- (sdn.byte S) 48)]) Scale true)
        (sdn.number-after-integer S O Sign Digits Scale)))

(define sdn.number-after-integer
  "" _ Sign Digits Scale -> [Digits Sign Scale]
  S O Sign Digits Scale -> (sdn.number-fraction (tlstr S) (+ O 1) Sign Digits 0)
    where (= (sdn.byte S) 46)
  S O Sign Digits Scale -> (sdn.number-exponent (tlstr S) (+ O 1) Sign Digits Scale 1 [] false)
    where (element? (sdn.byte S) [69 101])
  _ O _ _ _ -> (sdn.error invalid-number O "invalid number syntax"))

(define sdn.number-fraction
  "" O _ _ 0 -> (sdn.error invalid-number O "fraction requires digits")
  "" _ Sign Digits Count -> [Digits Sign Count]
  S O Sign Digits Count ->
    (if (sdn.digit? (sdn.byte S))
        (sdn.number-fraction (tlstr S) (+ O 1) Sign
          (append Digits [(- (sdn.byte S) 48)]) (+ Count 1))
        (if (= Count 0) (sdn.error invalid-number O "fraction requires digits")
          (if (element? (sdn.byte S) [69 101])
              (sdn.number-exponent (tlstr S) (+ O 1) Sign Digits Count 1 [] false)
              (sdn.error invalid-number O "invalid fraction")))))

(define sdn.number-exponent
  "" O _ _ _ _ _ false -> (sdn.error invalid-number O "exponent requires digits")
  "" _ Sign Digits Scale ExpSign ExpDigits true ->
    [Digits Sign (- Scale (* ExpSign (sdn.digits-number ExpDigits 0)))]
  S O Sign Digits Scale _ [] false ->
    (cond ((= (sdn.byte S) 45) (sdn.number-exponent (tlstr S) (+ O 1) Sign Digits Scale -1 [] false))
          ((= (sdn.byte S) 43) (sdn.number-exponent (tlstr S) (+ O 1) Sign Digits Scale 1 [] false))
          (true (sdn.number-exponent S O Sign Digits Scale 1 [] true)))
  S O Sign Digits Scale ExpSign ExpDigits Seen ->
    (if (sdn.digit? (sdn.byte S))
        (sdn.number-exponent (tlstr S) (+ O 1) Sign Digits Scale ExpSign
          (append ExpDigits [(- (sdn.byte S) 48)]) true)
        (sdn.error invalid-number O "invalid exponent")))

(define sdn.digits-number
  [] N -> N
  [D | Ds] N -> (sdn.digits-number Ds (+ (* N 10) D)))

(define sdn.lossless-number
  0 _ _ _ -> 0
  Coeff Scale _ O ->
    (if (<= Scale 0)
        (let N (* Coeff (sdn.pow 10 (- 0 Scale)))
          (if (> (sdn.abs N) 9007199254740991)
              (sdn.error invalid-number O "integer exceeds the lossless binary64 policy") N))
        (let Reduced (sdn.cancel-fives (sdn.abs Coeff) Scale)
          (if (> (hd (tl Reduced)) 0)
              (sdn.error invalid-number O "decimal is not exactly representable in binary64")
              (let N (/ Coeff (sdn.pow 10 Scale))
                (if (> (sdn.abs Coeff) 9007199254740991)
                    (sdn.error invalid-number O "decimal coefficient exceeds the lossless policy") N))))))

(define sdn.cancel-fives
  N 0 -> [N 0]
  N P -> (if (integer? (/ N 5))
             (sdn.cancel-fives (/ N 5) (- P 1))
             [N P]))

(define sdn.collection-room
  Items L O -> (if (>= (length Items)
                        (sdn.limit max-collection-length L (value sdn.*max-collection-length*)))
                   (sdn.error resource-limit O "collection length exceeded") true))

(define sdn.list
  S O D L Items -> (let K (sdn.check-depth D L O)
    (let Z (sdn.spacing S O)
      (let T (hd Z)
        (let P (hd (tl Z))
          (cond
            ((= T "") (sdn.error unexpected-eof P "unterminated list"))
            ((= (sdn.byte T) 93) [(reverse Items) (tlstr T) (+ P 1)])
            ((= (sdn.byte T) 124)
              (if (= Items []) (sdn.error invalid-list-tail P "list pipe requires a head")
                (let A (sdn.spacing (tlstr T) (+ P 1))
                  (if (not (hd (tl (tl A))))
                      (sdn.error invalid-list-tail P "list pipe requires separators")
                      (if (= (hd A) "") (sdn.error invalid-list-tail (hd (tl A)) "missing list tail")
                        (let R (sdn.datum (hd A) (hd (tl A)) D L)
                          (let E (sdn.spacing (hd (tl R)) (hd (tl (tl R))))
                            (if (or (= (hd E) "") (not (= (sdn.byte (hd E)) 93)))
                                (sdn.error invalid-list-tail (hd (tl E)) "pipe tail must be final")
                                [(sdn.prepend-all Items (hd R)) (tlstr (hd E)) (+ (hd (tl E)) 1)]))))))))
            (true
              (let Room (sdn.collection-room Items L P)
                (let R (sdn.datum T P D L)
                  (let Sep (sdn.require-separator (hd (tl R)) (hd (tl (tl R))))
                    (sdn.list (hd Sep) (hd (tl Sep)) D L (cons (hd R) Items))))))))))))

(define sdn.prepend-all
  [] Tail -> Tail
  RevHeads Tail -> (sdn.prepend-forward (reverse RevHeads) Tail))

(define sdn.prepend-forward
  [] Tail -> Tail
  [H | Hs] Tail -> (cons H (sdn.prepend-forward Hs Tail)))

(define sdn.vector
  S O D L Items -> (let K (sdn.check-depth D L O)
    (let Z (sdn.spacing S O)
      (let T (hd Z)
        (let P (hd (tl Z))
          (cond
            ((= T "") (sdn.error unexpected-eof P "unterminated vector"))
            ((= (sdn.byte T) 62) [(sdn.make-vector (reverse Items)) (tlstr T) (+ P 1)])
            ((element? (sdn.byte T) [41 93 124]) (sdn.error mismatched-delimiter P "expected >"))
            (true (let Room (sdn.collection-room Items L P)
              (let R (sdn.datum T P D L)
                (let Sep (sdn.require-separator (hd (tl R)) (hd (tl (tl R))))
                  (sdn.vector (hd Sep) (hd (tl Sep)) D L (cons (hd R) Items))))))))))))

(define sdn.make-vector
  Items -> (sdn.fill-vector
             (address-> (absvector (+ (length Items) 1)) 0 (length Items)) 1 Items))

(define sdn.fill-vector
  V _ [] -> V
  V N [X | Xs] -> (sdn.fill-vector (address-> V N X) (+ N 1) Xs))

(define sdn.tuple
  S O D L -> (let K (sdn.check-depth D L O)
    (let Z (sdn.spacing S O)
      (let T (hd Z)
        (let P (hd (tl Z))
          (if (= T "") (sdn.error unexpected-eof P "unterminated tuple")
            (let A (sdn.atom T P L)
              (if (or (not (symbol? (hd A))) (not (= (hd A) @p)))
                  (sdn.error invalid-tuple P "parenthesized data must begin @p")
                  (let S1 (sdn.require-separator (hd (tl A)) (hd (tl (tl A))))
                    (if (or (= (hd S1) "") (= (sdn.byte (hd S1)) 41))
                        (sdn.error invalid-tuple (hd (tl S1)) "tuple requires two elements")
                        (let First (sdn.datum (hd S1) (hd (tl S1)) D L)
                          (let S2 (sdn.require-separator (hd (tl First)) (hd (tl (tl First))))
                            (if (or (= (hd S2) "") (= (sdn.byte (hd S2)) 41))
                                (sdn.error invalid-tuple (hd (tl S2)) "tuple requires two elements")
                                (let Second (sdn.datum (hd S2) (hd (tl S2)) D L)
                                  (sdn.tuple-rest (hd (tl Second)) (hd (tl (tl Second))) D L
                                    [(hd Second) (hd First)])))))))))))))))

(define sdn.tuple-rest
  S O D L Rev -> (let Z (sdn.spacing S O)
    (let T (hd Z)
      (let P (hd (tl Z))
        (cond
          ((= T "") (sdn.error unexpected-eof P "unterminated tuple"))
          ((= (sdn.byte T) 41) [(sdn.right-tuple (reverse Rev)) (tlstr T) (+ P 1)])
          ((element? (sdn.byte T) [62 93 124]) (sdn.error mismatched-delimiter P "expected )"))
          (true (let Room (sdn.collection-room Rev L P)
            (let R (sdn.datum T P D L)
              (sdn.tuple-rest (hd (tl R)) (hd (tl (tl R))) D L (cons (hd R) Rev))))))))))

(define sdn.right-tuple
  [A B] -> (@p A B)
  [A | Rest] -> (@p A (sdn.right-tuple Rest)))

\\ SDN equality is structural and deliberately independent of host object
\\ identity (not every Shen port gives vectors/tuples structural `=`).
(define sdn.equal?
  X Y -> (and (tuple? X) (and (tuple? Y)
           (and (sdn.equal? (fst X) (fst Y)) (sdn.equal? (snd X) (snd Y)))))
    where (or (tuple? X) (tuple? Y))
  X Y -> (and (vector? X) (and (vector? Y)
           (and (= (limit X) (limit Y)) (sdn.equal-vectors? X Y 1 (limit X)))))
    where (or (vector? X) (vector? Y))
  X Y -> (and (cons? X) (and (cons? Y)
           (and (sdn.equal? (hd X) (hd Y)) (sdn.equal? (tl X) (tl Y)))))
    where (or (cons? X) (cons? Y))
  X Y -> (= X Y))

(define sdn.equal-vectors?
  _ _ N Max -> true where (> N Max)
  X Y N Max -> (and (sdn.equal? (<-vector X N) (<-vector Y N))
                    (sdn.equal-vectors? X Y (+ N 1) Max)))

\\ Canonical encoder.  SDN 0.1 defines only one required encoding profile, so
\\ sdn.encode and sdn.canonical-encode are aliases.
(define sdn.encode
  X -> (sdn.canonical-encode X))

(define sdn.canonical-encode
  X -> (cond
    ((string? X) (sdn.encode-string X))
    ((boolean? X) (if X "true" "false"))
    ((number? X) (sdn.encode-number X))
    ((symbol? X) (sdn.encode-symbol X))
    ((tuple? X) (cn "(@p " (cn (sdn.canonical-encode (fst X))
                       (cn " " (cn (sdn.canonical-encode (snd X)) ")")))))
    ((vector? X) (cn "<" (cn (sdn.encode-vector X 1 (limit X)) ">")))
    ((or (cons? X) (= X [])) (sdn.encode-list X))
    (true (sdn.error unexpected-token 0 "unsupported Shen runtime value"))))

(define sdn.encode-number
  N -> "0" where (= N 0)
  N -> (let S (str N) (let Check (sdn.parse-number S 0 []) S)) where (integer? N)
  N -> (let S (sdn.canonical-decimal (str N))
         (let Check (sdn.parse-number S 0 []) S)))

(define sdn.canonical-decimal
  S -> S)  \\ shen-lua already emits shortest lowercase-free decimal notation.

(define sdn.encode-symbol
  S -> (let Name (str S)
    (if (and (sdn.bare-symbol? Name true)
             (not (= Name "true"))
             (not (= Name "false"))
             (not (sdn.number-leading? Name)))
        Name
        (cn "#s" (sdn.encode-string Name)))))

(define sdn.encode-string
  S -> (let Valid (sdn.validate-utf8 S 0)
         (cn (n->string 34) (cn (sdn.escape-string S) (n->string 34)))))

(define sdn.escape-string
  "" -> ""
  S -> (let B (sdn.byte S)
    (cn (cond
      ((= B 34) (cn (n->string 92) (n->string 34)))
      ((= B 92) (cn (n->string 92) (n->string 92)))
      ((= B 8) (cn (n->string 92) "b"))
      ((= B 12) (cn (n->string 92) "f"))
      ((= B 10) (cn (n->string 92) "n"))
      ((= B 13) (cn (n->string 92) "r"))
      ((= B 9) (cn (n->string 92) "t"))
      ((< B 32) (cn (n->string 92) (cn "u00" (sdn.hex-byte B))))
      (true (hdstr S)))
      (sdn.escape-string (tlstr S)))))

(define sdn.hex-byte
  B -> (cn (sdn.hex-digit (sdn.quotient B 16)) (sdn.hex-digit (sdn.remainder B 16))))

(define sdn.hex-digit
  N -> (n->string (+ 48 N)) where (< N 10)
  N -> (n->string (+ 87 N)))

(define sdn.encode-vector
  _ N Max -> "" where (> N Max)
  V N Max -> (cn (sdn.canonical-encode (<-vector V N))
                 (if (= N Max) "" (cn " " (sdn.encode-vector V (+ N 1) Max)))))

(define sdn.encode-list
  [] -> "[]"
  X -> (cn "[" (cn (sdn.encode-list-body X) "]")))

(define sdn.encode-list-body
  [H | T] -> (cn (sdn.canonical-encode H)
                  (cond ((= T []) "")
                        ((cons? T) (cn " " (sdn.encode-list-body T)))
                        (true (cn " | " (sdn.canonical-encode T))))))
