#lang racket

;; Prefix-calculator Options (input / batch)
;; Usage:
;;   racket prefix-calc.rkt        ; User Input Mode (prompts)
;;   racket prefix-calc.rkt -b     ; batch mode (no prompts; only results/errors)

(define prompt?
  (let ([args (current-command-line-arguments)])
    (cond
      [(= (vector-length args) 0) #t]
      [(string=? (vector-ref args 0) "-b") #f]
      [(string=? (vector-ref args 0) "--batch") #f]
      [else #t])))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Tokenizer
;; - Splits an input string into tokens:
;;   numbers (allow optional leading '-'), operators + * / -, history refs $n,
;;   parentheses are not used but the tokenizer can isolate them if present.
;; - Important: treats "-3" as a single numeric token; a standalone "-" is a unary operator.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (tokenize str)
  (define chars (string->list str))
  (define (helper lst current acc)
    (cond
      [(null? lst)
       (reverse (if (null? current)
                    acc
                    (cons (list->string (reverse current)) acc)))]
      [else
       (let* ([c (car lst)]
              [next (if (null? (cdr lst)) #f (car (cdr lst)))])
         (cond
           ;; whitespace: finish current token (if any)
           [(char-whitespace? c)
            (helper (cdr lst) '()
                    (if (null? current)
                        acc
                        (cons (list->string (reverse current)) acc)))]
           
           ;; handling our operators, these values are ALWAYS treated as such
           [(member c '(#\+ #\* #\/ #\( #\)))
            (helper (cdr lst) '()
                    (cons (string c)
                          (if (null? current)
                              acc
                              (cons (list->string (reverse current)) acc))))]
           
           ;; Be careful with '-' we DONT want subtraction, just a unary negate
           ;; if '-' is followed immediately by a digit, it's part of a number token (e.g. "-3")
           [(and (char=? c #\-) (not (char-whitespace? next)) (char-numeric? next))
            (helper (cdr lst) (cons c current) acc)]
           
           ;; We use '$' to reference previous values
           [(char=? c #\$)
            (helper (cdr lst) (cons c current) acc)]
           
           ;; handling anything that isnt a number
           [else
            (helper (cdr lst) (cons c current) acc)]))]))
  
  ;; storing the result
  (let ([raw (helper chars '() '())])
    ;; filter out extra things we dont care about 
    (filter (lambda (t) (not (string=? t ""))) raw)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Evaluation (prefix)
;; - eval-tokens: parses an expression from the front of a token list and returns
;;   two values: the numeric result and the remaining tokens.
;; - On error, raises an exception.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (string-integer? s)
  (and (string? s)
       (regexp-match? #px"^-?[0-9]+$" s)))

(define (string-number? s)
  (and (string? s)
       (regexp-match? #px"^-?[0-9]+(\\.[0-9]+)?$" s)))

(define (string-history-ref? s)
  (and (string? s) (regexp-match? #px"^\\$[0-9]+$" s)))

(define (nth-history-value history n)
  ;; history is stored as most-recent-first (cons). IDs are 1-based in insertion order.
  ;; To get ID n (1-based earliest-first), reverse history and fetch index n-1.
  (let ([len (length history)])
    (when (or (not (integer? n)) (< n 1) (> n len))
      (error 'history "Invalid history reference"))
    (list-ref (reverse history) (sub1 n))))

(define (eval-tokens tokens history)
  (when (null? tokens) (error 'parse "Empty expression"))
  (let ([tok (car tokens)]
        [rest (cdr tokens)])
    (cond
      ;; How we store previous values and case for handling if the value isnt there
      [(string-history-ref? tok)
       (let* ([n-str (substring tok 1)]
              [n (string->number n-str)])
         (unless (and n (integer? n))
           (error 'parse "Invalid history number"))
         (values (nth-history-value history n) rest))]

      ;; numeric token (int or float)
      [(string-number? tok)
       (values (string->number tok) rest)]

      ;; unary negation in respect to our previous value 
      [(string=? tok "-")
       (let-values ([(val rem) (eval-tokens rest history)])
         (values (- val) rem))]

      ;; all of our binary operators in respect to the previous value
      [(or (string=? tok "+") (string=? tok "*") (string=? tok "/"))
       (let-values ([(v1 rem1) (eval-tokens rest history)])
         (let-values ([(v2 rem2) (eval-tokens rem1 history)])
           (cond
             [(string=? tok "+") (values (+ v1 v2) rem2)]
             [(string=? tok "*") (values (* v1 v2) rem2)]
             [(string=? tok "/")
              (when (zero? v2) (error 'math "Division by zero"))
              (let* ([a (truncate v1)]
                     [b (truncate v2)]
                     [res (quotient a b)])
                (values res rem2))]
             [else (error 'parse "Unknown binary operator")])))] ; unknown operator mentioned
      [else
       (error 'parse (format "Unknown token: ~a" tok))]))) ; reference to an unknown token

;;;;;;;;;;;;;;;;;;;;;;;;;
;; Main REPL / batch loop
;;;;;;;;;;;;;;;;;;;;;;;;;

(define (print-prompt)
  (when prompt?
    (display "> ")
    (flush-output)))

(define (print-result-and-add history result)
  ;; ID is the order added (1-based), meaning it goes from 1 upwards for previous values
  (let ([id (+ 1 (length history))])
    (displayln (format "~a: ~a" id (real->double-flonum result)))
    (cons result history))) ;; add to front to be put in the result history

(define (handle-input-line line history)
  (define trimmed (string-trim line))
  (cond
    [(string=? trimmed "") history]
    [(string-ci=? trimmed "quit") (begin (exit))] ; if quit is inputted then leave
    [else
     (let ([toks (tokenize trimmed)])
       (with-handlers ([exn:fail?
                        (lambda (e)
                          ;; print error if the execution fails 
                          (displayln (format "Error: Invalid Expression"))
                          history)])
         (let-values ([(val rem) (eval-tokens toks history)])
           (when (not (null? rem)) ;; error if there are extra tokens after valid expression
             (error 'parse "Extra tokens after valid expression"))
           (print-result-and-add history val))))]))

(define (main-loop history)
  (print-prompt)
  (let ([line (with-handlers ([exn:fail:read?
                                (lambda (e)
                                  (exit))])
                (read-line))])
    (cond
      [(eof-object? line) (exit)]
      [else
       (define new-history (handle-input-line line history))
       (main-loop new-history)])))

;;;;;;;;;
;; Start
;;;;;;;;;

;; initial empty history
(main-loop '())
;;;;;;;;
;; test
;;;;;;;;

