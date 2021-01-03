
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; MODULE      : compat-s7.scm
;; DESCRIPTION : compatability layer for S7
;; COPYRIGHT   : (C) 2021 Massimiliano Gubinelli
;;
;; This software falls under the GNU general public license version 3 or later.
;; It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
;; in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(texmacs-module (kernel boot compat-s7))

;;; certain Scheme versions do not define 'filter'
(if (not (defined? 'filter))
    (define-public (filter pred? l)
      (apply append (map (lambda (x) (if (pred? x) (list x) (list))) l))))

;; curried define
(define base-define define)
(define-public-macro (curried-define head . body)
    (if (pair? head)
      `(,curried-define ,(car head) (lambda ,(cdr head) ,@body))
      `(,base-define ,head ,@body)))
(varlet *texmacs-user-module* 'define curried-define)

(define-public (noop . l) (if #f #f #f))

(define-public (acons key datum alist) (cons (cons key datum) alist))

(define-public (symbol-append . l)
   (string->symbol (apply string-append (map symbol->string l))))

(define-public (map-in-order . l) (apply map l))

(define-public lazy-catch catch)

(define-public (last-pair lis)
;;  (check-arg pair? lis last-pair)
  (let lp ((lis lis))
    (let ((tail (cdr lis)))
      (if (pair? tail) (lp tail) lis))))


(define-public (seed->random-state seed) (random-state seed))


(define-public (copy-tree tree)
  (let loop ((tree tree))
    (if (pair? tree)
        (cons (loop (car tree)) (loop (cdr tree)))
        tree)))


(define-public (assoc-set! l what val)
  (let ((b (assoc what l)))
    (if b (set! (cdr b) val) (set! l (cons (cons what val) l)))
    l))

;;FIXME: assoc-set! is tricky to use, maybe just get rid in the code
(define-public (assoc-set! l what val)
  (let ((b (assoc what l)))
    (if b (set! (cdr b) val) (set! l (cons (cons what val) l)))
    l))

(define-public (assoc-ref l what)
  (let ((b (assoc what l)))
    (if b (cdr b) #f)))

(define-public (sort l op) (sort! (copy l) op))

(define-public (force-output) (flush-output-port *stdout*))

;;;@ Return the index of the first occurence of chr in str, or #f
;; From SLIB/strsrch.scm
(define-public (string-index str chr)
  (define len (string-length str))
  (do ((pos 0 (+ 1 pos)))
      ((or (>= pos len) (char=? chr (string-ref str pos)))
       (and (< pos len) pos))))
;@
;; From SLIB/strsrch.scm
(define-public (string-rindex str chr)
  (do ((pos (+ -1 (string-length str)) (+ -1 pos)))
      ((or (negative? pos) (char=? (string-ref str pos) chr))
       (and (not (negative? pos)) pos))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (string-split s ch)
  (let ((len (length s)))
    (let f ((start 0) (acc ()))
      (if (< start len)
        (let ((end (+ (or (char-position ch s start) (- len 1)) 1)))
           (f end (cons (substring s start end)  acc)))
        (reverse acc)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;guile-style records

;(define tmtable-type (make-record-type "tmtable" '(nrows ncols cells formats)))
;(define tmtable-record (record-constructor tmtable-type))
;(tm-define tmtable? (record-predicate tmtable-type))
;(tm-define tmtable-nrows (record-accessor tmtable-type 'nrows))
;(tm-define tmtable-ncols (record-accessor tmtable-type 'ncols))
;(tm-define tmtable-cells (record-accessor tmtable-type 'cells))
;(define tmtable-formats (record-accessor tmtable-type 'formats))

(define-public (make-record-type type fields)
  (inlet 'type type 'fields fields))

(define-public (record-constructor rec-type)
  (eval `(lambda ,(rec-type 'fields)
     (inlet 'type ,(rec-type 'type) ,@(map (lambda (f) (values (list 'quote f) f)) (rec-type 'fields))))))
 
(define-public-macro (record-accessor rec-type field)
  `(lambda (rec) (rec ,field)))

(define-public (record-predicate rec-type)
  (lambda (rec) (eq? (rec 'type) (rec-type 'type))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; From S7/r7rs.scm

;; delay and force: ugh
;;   this implementation is based on the r7rs spec

(define-public (make-promise done? proc)
  (list (cons done? proc)))

(define-public-macro (delay-force expr)
  `(make-promise #f (lambda () ,expr)))

(define-public-macro (delay expr) ; "delay" is taken damn it
  (list 'delay-force (list 'make-promise #t (list 'lambda () expr))))

(define-public (force promise)
  (if (caar promise)
      ((cdar promise))
      (let ((promise* ((cdar promise))))
        (if (not (caar promise))
            (begin
              (set-car! (car promise) (caar promise*))
              (set-cdr! (car promise) (cdar promise*))))
        (force promise))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; hashing (from the SRFI reference implementation)

(define *default-bound* (- (expt 2 29) 3))

(define (%string-hash s ch-conv bound)
  (let ((hash 31)
    (len (string-length s)))
    (do ((index 0 (+ index 1)))
      ((>= index len) (modulo hash bound))
      (set! hash (modulo (+ (* 37 hash)
                (char->integer (ch-conv (string-ref s index))))
             *default-bound*)))))

(define (string-hash s . maybe-bound)
  (let ((bound (if (null? maybe-bound) *default-bound* (car maybe-bound))))
    (%string-hash s (lambda (x) x) bound)))

(define (string-ci-hash s . maybe-bound)
  (let ((bound (if (null? maybe-bound) *default-bound* (car maybe-bound))))
    (%string-hash s char-downcase bound)))

(define (symbol-hash s . maybe-bound)
  (let ((bound (if (null? maybe-bound) *default-bound* (car maybe-bound))))
    (%string-hash (symbol->string s) (lambda (x) x) bound)))

(define (vector-hash v bound)
  (let ((hashvalue 571)
    (len (vector-length v)))
    (do ((index 0 (+ index 1)))
      ((>= index len) (modulo hashvalue bound))
      (set! hashvalue (modulo (+ (* 257 hashvalue) (hash (vector-ref v index)))
                  *default-bound*)))))

(define-public (hash obj . maybe-bound)
  (let ((bound (if (null? maybe-bound) *default-bound* (car maybe-bound))))
    (cond ((integer? obj) (modulo obj bound))
      ((string? obj) (string-hash obj bound))
      ((symbol? obj) (symbol-hash obj bound))
      ((real? obj) (modulo (+ (numerator obj) (denominator obj)) bound))
      ((number? obj)
       (modulo (+ (hash (real-part obj)) (* 3 (hash (imag-part obj))))
           bound))
      ((char? obj) (modulo (char->integer obj) bound))
      ((vector? obj) (vector-hash obj bound))
      ((pair? obj) (modulo (+ (hash (car obj)) (* 3 (hash (cdr obj))))
                   bound))
      ((null? obj) 0)
      ((not obj) 0)
      ((procedure? obj) (error "hash: procedures cannot be hashed" obj))
      (else 1))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TODO/FIXME

;getlogin
; char-set-adjoin

(define-public (getpid) 1)
(define-public (access? . l) #f)
(define-public R_OK #f)

(define-public (current-time) 100)