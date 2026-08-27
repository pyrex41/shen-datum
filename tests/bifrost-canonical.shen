\\ Canonical encodings are printed as an agreement oracle across ports.
(load "sdn.shen")

(define bifrost-canonical.run
  -> (do
    (output "~A~%" (sdn.canonical-encode (sdn.decode " [one | [two three]] ")))
    (do
      (output "~A~%" (sdn.canonical-encode (sdn.decode "(@p one two three)")))
      (do
        (output "~A~%" (sdn.canonical-encode (sdn.decode "+1.0e+00")))
        (do
          (output "~A~%" (sdn.canonical-encode [name | "Ada"]))
          (output "SDN CANONICAL PASS~%"))))))

(bifrost-canonical.run)
