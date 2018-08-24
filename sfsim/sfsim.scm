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

(define state1 (make-state '(0 0.3 0) '(0 0 0) (quaternion-rotation 0 '(1 0 0)) '(0.0 0.0 0.0)))
(define state2 (make-state '(0 -0.3 0) '(0 0 0) (quaternion-rotation 0 '(0 0 1)) '(0.0 0.0 0.0)))
(define gear  (make-spring 0.05 0.0))
(define lander (make-lander state1 gear))

(define g '(0 -0.5 0))

(define m1 1)
(define m2 5.9742e+24)
(define mg 0.05)
(define K 10.0)
(define D 0.1)
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
(define max-depth 20)

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

(define (show-lander lander)
  (let* [(b   (make-bytevector (* 4 4 4)))
         (mat (rotation-matrix (orientation (state lander))))
         (hom (concatenate (homogeneous-matrix mat (position (state lander)))))]
    (for-each (lambda (i v) (bytevector-ieee-single-native-set! b (* i 4) v)) (iota (length hom)) hom)
    (set-gl-matrix-mode (matrix-mode modelview))
    (gl-load-matrix b #:transpose #t)
    (glPointSize 5)
    (gl-begin (begin-mode points)
      (gl-color 1 0 1)
      (apply gl-vertex (+ (list 0 (- h) 0) (list 0 (position (car (gears lander))) 0))))
    (gl-scale w h d)
    (gl-color 0 1 0)
    (glut-wire-cube 1.0)))

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
  (show-lander lander)
  (show-state state2 scale)
  (swap-buffers))

(define* (timestep state1 state2 gear dt #:optional (recursion 0))
  (let [(update1 (runge-kutta state1 dt (lander-change m1 inertia1 '(0 0 0) K D 0.1)))
        (update2 (runge-kutta state2 dt (state-change m2 inertia2 '(0 0 0))))]
    (let* [(closest  (gjk-algorithm (body1 (state update1)) (body2 update2)))
           (distance       (norm (- (car closest) (cdr closest))))]
      (if (and (eqv? recursion 0) (>= distance epsilon))
        (list update1 update2)
        (if (or (>= distance epsilon) (>= recursion max-depth))
          (let [(c (collision (state update1) update2 m1 m2 inertia1 inertia2 closest loss mu ve))]
            (list (apply make-lander (car c) (gears update1)) (cdr c) gear))
          (timestep state1 state2 gear (/ dt 2) (1+ recursion)))))))

(define (on-idle)
  (let [(dt (min dtmax (elapsed time #t)))]
    (let [(update (timestep lander state2 gear dt))]
      (set! lander (car   update))
      (set! state2 (cadr  update)))
    (post-redisplay)))

(initialize-glut (program-arguments) #:window-size '(640 . 480) #:display-mode (display-mode rgb double))
(set! main-window (make-window "sfsim"))
(set-display-callback on-display)
(set-reshape-callback on-reshape)
(set-idle-callback on-idle)
(set! time (clock))
(glut-main-loop)
