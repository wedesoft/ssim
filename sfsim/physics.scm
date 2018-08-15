(define-module (sfsim physics)
  #:use-module (oop goops)
  #:use-module (ice-9 curried-definitions)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-19)
  #:use-module (srfi srfi-26)
  #:use-module (sfsim util)
  #:use-module (sfsim linear-algebra)
  #:use-module (sfsim quaternion)
  #:export (clock elapsed cuboid-inertia runge-kutta inertia-body angular-velocity
            particle-position particle-speed deflect support-point center-of-gravity
            closest-simplex-points gjk-algorithm collision-impulse))


(define (clock)
  "Get current time with high precision"
  (current-time))

(define* (elapsed reference #:optional (reset #f))
  "Return time elapsed and optionally reset the clock"
  (let [(difference (time-difference (current-time) reference))]
    (if reset (add-duration! reference difference))
    (+ (time-second difference) (* 1e-9 (time-nanosecond difference)))))

(define (runge-kutta y0 dt dy)
  "4th order Runge-Kutta method"
  (let* [(dt2 (/ dt 2))
         (k1  (dy y0                0  ))
         (k2  (dy (+ y0 (* k1 dt2)) dt2))
         (k3  (dy (+ y0 (* k2 dt2)) dt2))
         (k4  (dy (+ y0 (* k3 dt )) dt ))]
    (+ y0 (* (+ k1 (* k2 2) (* k3 2) k4) (/ dt 6)))))

(define (cuboid-inertia mass width height depth)
  "Determine diagonal elements of a cuboid's inertial matrix"
  (diagonal (list (* (/ mass 12) (+ (expt height 2) (expt depth  2)))
                  (* (/ mass 12) (+ (expt width  2) (expt depth  2)))
                  (* (/ mass 12) (+ (expt width  2) (expt height 2))))))

(define ((inertia-body mat) orientation)
  "Rotate inertia matrix MAT into world frame"
  (rotate-matrix orientation mat))

(define (angular-velocity inertia orientation angular-momentum)
  "Angular velocity determined using the angular momentum and the (rotated) inertia tensor"
  (dot (inverse (inertia orientation)) angular-momentum))

(define-method (particle-position center orientation radius-vector)
  "Determine position of a rigid body's particle"
  (+ center (rotate-vector orientation radius-vector)))

(define-method (particle-speed inertia center orientation body-velocity angular-momentum particle-pos)
  "Determine speed of a rigid body's particle"
  (+ body-velocity (cross-product (angular-velocity inertia orientation angular-momentum) (- particle-pos center))))

(define (support-point direction points)
  "Get outermost point of POINTS in given DIRECTION."
  (argmax (cut inner-product direction <>) points))

(define (center-of-gravity points)
  "Compute average of given points"
  (* (reduce + #f points) (/ 1 (length points))))

(define (closest-simplex-points simplex-a simplex-b)
  "Determine closest point pair of two simplices"
  (let* [(observation   (- (car simplex-a) (car simplex-b)))
         (design-matrix (- observation (transpose (- (cdr simplex-a) (cdr simplex-b)))))
         (factors       (least-squares design-matrix observation))]
      (if (and (every positive? factors) (< (reduce + 0 factors) 1))
        (cons (cons (fold + (car simplex-a) (map * factors (map (cut - <> (car simplex-a)) (cdr simplex-a))))
                    (fold + (car simplex-b) (map * factors (map (cut - <> (car simplex-b)) (cdr simplex-b)))))
              (cons simplex-a simplex-b))
        (argmin (lambda (result) (norm (- (caar result) (cdar result))))
                (map closest-simplex-points (leave-one-out simplex-a) (leave-one-out simplex-b))))))

(define (gjk-algorithm convex-a convex-b)
  "Get pair of closest points of two convex hulls each defined by a set of points"
  (let [(simplex-a '())
        (simplex-b '())
        (closest (cons (center-of-gravity convex-a) (center-of-gravity convex-b)))]
    (while #t
      (let* [(direction  (- (car closest) (cdr closest)))
             (candidates (cons (support-point (- direction) convex-a) (support-point direction convex-b)))]
        (if (>= (+ (inner-product direction (- direction)) 1e-12) (inner-product (- (car candidates) (cdr candidates)) (- direction)))
          (break closest))
        (let [(result (closest-simplex-points (cons (car candidates) simplex-a) (cons (cdr candidates) simplex-b)))]
          (set! closest (car result))
          (set! simplex-a (cadr result))
          (set! simplex-b (cddr result)))))))

(define (deflect relative-speed normal loss friction micro-speed)
  "Determine speed change necessary to deflect particle. If the particle is very slow, a lossless micro-collision is computed instead."
  (let* [(normal-speed     (inner-product normal relative-speed))
         (tangential-speed (orthogonal-component normal relative-speed))
         (normal-target    (if (>= normal-speed (- micro-speed)) (- micro-speed normal-speed) (* (- loss 2) normal-speed)))
         (friction-target  (* friction normal-target))]
    (- (* normal-target normal) (* friction-target (normalize tangential-speed)))))

(define (collision-impulse speed-change mass-a mass-b inertia-a inertia-b orientation-a orientation-b radius-a radius-b)
  "Compute impulse of a collision of two objects"
  (let* [(direction (normalize speed-change))
         (impulse   (/ (norm speed-change)
                       (+ (/ 1 mass-a)
                          (/ 1 mass-b)
                          (inner-product direction (cross-product (dot (inverse (inertia-a orientation-a))
                                                                  (cross-product radius-a direction)) radius-a))
                          (inner-product direction (cross-product (dot (inverse (inertia-b orientation-b))
                                                                  (cross-product radius-b direction)) radius-b)))))]
    (* impulse direction)))
