#lang racket

;; Prefix-calculator (interactive / batch)
;; Usage:
;;   racket prefix-calc.rkt        ; interactive mode (prompts)
;;   racket prefix-calc.rkt -b     ; batch mode (no prompts; only results/errors)

(define prompt?
  (let ([args (current-command-line-arguments)])
    (cond
      [(= (vector-length args) 0) #t]
      [(string=? (vector-ref args 0) "-b") #f]
      [(string=? (vector-ref args 0) "--batch") #f]
      [else #t])))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Tokenizer
;; - Splits an input string into tokens:
;;   numbers (allow optional leading '-'), operators + * / -, history refs $n,
;;   parentheses are not used but the tokenizer can isolate them if present.
;; - Important: treats "-3" as a single numeric token; a standalone "-" is a unary operator.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
           
           ;; treat + * / ( ) as separate tokens (these are always operators)
           [(member c '(#\+ #\* #\/ #\( #\)))
            (helper (cdr lst) '()
                    (cons (string c)
                          (if (null? current)
                              acc
                              (cons (list->string (reverse current)) acc))))]
           
           ;; handle '-' carefully:
           ;; if '-' is followed immediately by a digit, it's part of a number token (e.g. "-3")
           [(and (char=? c #\-) (not (char-whitespace? next)) (char-numeric? next))
            (helper (cdr lst) (cons c current) acc)]
           
           ;; '$' begins a history reference token (like $12)
           [(char=? c #\$)
            (helper (cdr lst) (cons c current) acc)]
           
           ;; numeric or part of a word
           [else
            (helper (cdr lst) (cons c current) acc)]))]))
  
  ;; result
  (let ([raw (helper chars '() '())])
    ;; filter out empty tokens if any
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
      ;; history ref $n
      [(string-history-ref? tok)
       (let* ([n-str (substring tok 1)]
              [n (string->number n-str)])
         (unless (and n (integer? n))
           (error 'parse "Invalid history number"))
         (values (nth-history-value history n) rest))]

      ;; numeric token (int or float)
      [(string-number? tok)
       (values (string->number tok) rest)]

      ;; unary negation operator '-'
      [(string=? tok "-")
       (let-values ([(val rem) (eval-tokens rest history)])
         (values (- val) rem))]

      ;; binary operators +, *, /
      [(or (string=? tok "+") (string=? tok "*") (string=? tok "/"))
       (let-values ([(v1 rem1) (eval-tokens rest history)])
         (let-values ([(v2 rem2) (eval-tokens rem1 history)])
           (cond
             [(string=? tok "+") (values (+ v1 v2) rem2)]
             [(string=? tok "*") (values (* v1 v2) rem2)]
             [(string=? tok "/")
              ;; integer division with truncation toward zero
              (when (zero? v2) (error 'math "Division by zero"))
              (let* ([a (truncate v1)]
                     [b (truncate v2)]
                     [res (quotient a b)]) ; integer division
                (values res rem2))]
             [else (error 'parse "Unknown binary operator")])))]
      [else
       (error 'parse (format "Unknown token: ~a" tok))])))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Main REPL / batch loop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (print-prompt)
  (when prompt?
    (display "> ")
    (flush-output)))

(define (print-result-and-add history result)
  ;; ID is the order added (1-based). History before adding contains previous results.
  (let ([id (+ 1 (length history))])
    ;; convert to float via real->double-flonum then display
    (displayln (format "~a: ~a" id (real->double-flonum result)))
    (cons result history))) ;; add to front (most-recent-first)

(define (handle-input-line line history)
  (define trimmed (string-trim line))
  (cond
    [(string=? trimmed "") history] ; ignore blank lines
    [(string-ci=? trimmed "quit") (begin (exit))] ; quit immediately
    [else
     (let ([toks (tokenize trimmed)])
       (with-handlers ([exn:fail?
                        (lambda (e)
                          ;; When an error occurs, print a message prefixed by "Error:"
                          ;; In batch mode we must only print results/errors.
                          (displayln (format "Error: Invalid Expression"))
                          history)])
         (let-values ([(val rem) (eval-tokens toks history)])
           (when (not (null? rem))
             (error 'parse "Extra tokens after valid expression"))
           (print-result-and-add history val))))]))

(define (main-loop history)
  (print-prompt)
  (let ([line (with-handlers ([exn:fail:read?
                                (lambda (e) ; handle EOF / read error by exiting quietly
                                  (exit))])
                (read-line))])
    (cond
      [(eof-object? line) (exit)]
      [else
       (define new-history (handle-input-line line history))
       (main-loop new-history)])))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; initial empty history
(main-loop '())
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; test
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

