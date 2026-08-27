\\ Raw UTF-8 fixture check, separate so ports with a broken multibyte tlstr
\\ primitive can still run the rest of the conformance suite.

(define sdn-unicode-test.run
  -> (trap-error
       (do (sdn.decode (read-file-as-string "fixtures/valid/unicode-and-comments.sdn"))
           (output "sdn-unicode-tests: passed~%"))
       (lambda E (simple-error (cn "SDN raw Unicode test failed: " (error-to-string E))))))

(sdn-unicode-test.run)
