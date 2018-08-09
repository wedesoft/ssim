(use-modules (srfi srfi-64)
             (sfsim linear-algebra)
             (sfsim physics)
             (sfsim state))


(test-begin "sfsim state")

(define s (make-state '(2 3 5) '(0.2 0.3 0.5) 1.0 '(0.1 0.2 0.3)))
(test-group "state struct"
  (test-equal "position of state"
    '(2 3 5) (position s))
  (test-equal "position of state"
    '(0.2 0.3 0.5) (speed s))
  (test-equal "quaternion orientation of state"
    1.0 (orientation s))
  (test-equal "angular momentum of state"
    '(0.1 0.2 0.3) (angular-momentum s)))

(test-group "scalar multiplication"
  (test-equal "multiply position"
    '(4 6 10) (position (* s 2)))
  (test-equal "multiply speed"
    '(0.4 0.6 1.0) (speed (* s 2)))
  (test-equal "multiply orientation"
    2.0 (orientation (* s 2)))
  (test-equal "multiply angular momentum"
    '(0.2 0.4 0.6) (angular-momentum (* s 2))))

(define s2 (make-state '(3 5 7) '(0.3 0.5 0.7) 0.1 '(0.5 0.3 0.4)))
(test-group "add states"
  (test-equal "add position"
    '(5 8 12) (position (+ s s2)))
  (test-equal "add speed"
    '(0.5 0.8 1.2) (speed (+ s s2)))
  (test-equal "add orientation"
    1.1 (orientation (+ s s2)))
  (test-equal "angular momentum"
    '(0.6 0.5 0.7) (angular-momentum (+ s s2))))

(define s (make-state '(2 3 5) '(0 0 0) 1.0 '(0 0 0)))
(test-group "particle states"
  '(3.0 5.0 8.0) (particle-position s '(1 2 3)))

(test-end "sfsim state")