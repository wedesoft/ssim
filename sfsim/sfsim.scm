#!/usr/bin/env guile
!#
(use-modules (system foreign)
             (rnrs bytevectors)
             (ice-9 optargs)
             (srfi srfi-1)
             (srfi srfi-19)
             (srfi srfi-26)
             (glut)
             (gl)
             (gl low-level)
             (sfsim linear-algebra)
             (sfsim physics)
             (sfsim quaternion)
             (sfsim util))


(define glut (dynamic-link "libglut"))
(define glut-wire-cube (pointer->procedure void (dynamic-func "glutWireCube" glut) (list double)))

(define time #f)
(define main-window #f)

(define state1 (make-state '(0 0.3 0) '(0 -0.1 0) (quaternion-rotation (/ 3.1415926 2) '(0 1 0)) '(0.0 0.1 0.01)))
(define state2 (make-state '(0 -0.3 0) '(0 0 0) (quaternion-rotation 0 '(0 0 1)) '(0.0 0.0 0.0)))

(define g '(0 -0.5 0))

(define m1 1)
(define m2 5.9742e+24)
(define mg 0.05)
(define K 20.0)
(define D 2.0)
(define w 0.5)
(define h 0.1)
(define d 0.25)
(define inertia1 (inertia-body (cuboid-inertia m1 w h d)))
(define inertia2 (inertia-body (cuboid-inertia m2 w h d)))

(define loss 0.6)
(define mu 0.6)

(define dtmax 0.05)
(define epsilon (* 0.5 (abs (cadr g)) (* dtmax dtmax)))
(define ve (sqrt (* 2 (abs (cadr g)) epsilon)))
(define max-depth 10)

(define speed-scale 0.3)

(define w2 (/ w 2))
(define h2 (/ h 2))
(define d2 (/ d 2))

(define corners1
  (list (list (- w2) (- h2) (- d2))
        (list (+ w2) (- h2) (- d2))
        (list (- w2) (+ h2) (- d2))
        (list (+ w2) (+ h2) (- d2))
        (list (- w2) (- h2) (+ d2))
        (list (+ w2) (- h2) (+ d2))
        (list (- w2) (+ h2) (+ d2))
        (list (+ w2) (+ h2) (+ d2))))

(define body1 (particle-positions corners1))

(define scale 3)

(define corners2 (* scale corners1))

(define body2 (particle-positions corners2))

(define (on-reshape width height)
  (let* [(aspect (/ width height))
         (h      1.0)
         (w      (* aspect h))]
    (gl-viewport 0 0 width height)
    (set-gl-matrix-mode (matrix-mode projection))
    (gl-load-identity)
    (gl-ortho (- w) w (- h) h -100 +100)))

(define (show-state state scale)
  (let* [(b   (make-bytevector (* 4 4 4)))
         (mat (rotation-matrix (orientation state)))
         (hom (concatenate (homogeneous-matrix mat (position state))))]
    (for-each (lambda (i v) (bytevector-ieee-single-native-set! b (* i 4) v)) (iota (length hom)) hom)
    (set-gl-matrix-mode (matrix-mode modelview))
    (gl-load-matrix b #:transpose #t)
    (gl-scale (* scale w) (* scale h) (* scale d))
    (gl-color 0 1 0)
    (glut-wire-cube 1.0)))

(define (on-display)
  (gl-clear (clear-buffer-mask color-buffer))
  (show-state state1 1)
  (show-state state2 scale)
  (swap-buffers))

(define* (timestep lander1 state2 dt #:optional (recursion 0))
  (let [(update1 (runge-kutta state1 dt (state-change m1 inertia1 '(0 -0.1 0) '(0 0 0))))
        (update2 (runge-kutta state2 dt (state-change m2 inertia2 '(0 0 0) '(0 0 0))))]
    (let* [(closest  (gjk-algorithm (body1 update1) (body2 update2)))
           (distance (norm (- (car closest) (cdr closest))))]
      (if (and (eqv? recursion 0) (>= distance epsilon)); TODO: check approach speed
        (list update1 update2)
        (if (or (>= distance epsilon) (>= recursion max-depth))
          (let [(c (collision update1 update2 m1 m2 inertia1 inertia2 closest loss mu ve))]
            (list (car c) (cdr c)))
          (timestep state1 state2 (/ dt 2) (1+ recursion)))))))

(define (on-idle)
  (let [(dt (min dtmax (elapsed time #t)))]
    (let [(update (timestep state1 state2 dt))]
      (set! state1 (car   update))
      (set! state2 (cadr  update)))
    (post-redisplay)))

(initialize-glut (program-arguments) #:window-size '(640 . 480) #:display-mode (display-mode rgb double))
(set! main-window (make-window "sfsim"))
(set-display-callback on-display)
(set-reshape-callback on-reshape)
(set-idle-callback on-idle)
(set! time (clock))
(glut-main-loop)
