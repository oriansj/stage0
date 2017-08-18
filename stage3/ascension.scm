;; Copyright (C) 2017 Jeremiah Orians
;; This file is part of stage0.
;;
;; stage0 is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; stage0 is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with stage0.  If not, see <http://www.gnu.org/licenses/>.

;; 2 level car/cdr
(define caar (lambda (x) (car (car x))))
(define cadr (lambda (x) (car (cdr x))))
(define cdar (lambda (x) (cdr (car x))))
(define cddr (lambda (x) (cdr (cdr x))))

; 3 level car/cdr
(define caaar (lambda (x) (car (car (car x)))))
(define caadr (lambda (x) (car (car (cdr x)))))
(define cadar (lambda (x) (car (cdr (car x)))))
(define caddr (lambda (x) (car (cdr (cdr x)))))
(define cdaar (lambda (x) (cdr (car (car x)))))
(define cdadr (lambda (x) (cdr (car (cdr x)))))
(define cddar (lambda (x) (cdr (cdr (car x)))))
(define cdddr (lambda (x) (cdr (cdr (cdr x)))))

; 4 level car/cdr
(define caaaar (lambda (x) (car (car (car (car x))))))
(define caaadr (lambda (x) (car (car (car (cdr x))))))
(define caadar (lambda (x) (car (car (cdr (car x))))))
(define caaddr (lambda (x) (car (car (cdr (cdr x))))))
(define cadaar (lambda (x) (car (cdr (car (car x))))))
(define cadadr (lambda (x) (car (cdr (car (cdr x))))))
(define caddar (lambda (x) (car (cdr (cdr (car x))))))
(define cadddr (lambda (x) (car (cdr (cdr (cdr x))))))
(define cdaaar (lambda (x) (cdr (car (car (car x))))))
(define cdaadr (lambda (x) (cdr (car (car (cdr x))))))
(define cdadar (lambda (x) (cdr (car (cdr (car x))))))
(define cdaddr (lambda (x) (cdr (car (cdr (cdr x))))))
(define cddaar (lambda (x) (cdr (cdr (car (car x))))))
(define cddadr (lambda (x) (cdr (cdr (car (cdr x))))))
(define cdddar (lambda (x) (cdr (cdr (cdr (car x))))))
(define cddddr (lambda (x) (cdr (cdr (cdr (cdr x))))))

; Append
(define append
	(lambda (x y)
		(cond
			((null? x) y)
			(#t (cons (car x) (append (cdr x) y))))))
(define string-append (lambda (x y) (list->string (append (string->list x) (string->list y)))))

; Assoc
(define assoc
	(lambda (x y)
		(cond
			((string=? (caar y) x) (car y))
			(#t (assoc x (cdr y))))))

; Get-index
(define get-index
	(lambda (number list)
		(if (null? list)
			nil
			(if (= 0 number)
				(car list)
				(get-index (- number 1) (cdr list))))))

; Reverse
(define reverse
	(lambda (l)
		(begin
			(define reving
				(lambda (list result)
					(cond
						((null? list) result)
						((list? list) (reving (cdr list) (cons (car list) result)))
						(#t (cons list result)))))
			(reving l nil))))

; Map
(define map
	(lambda (f l)
		(if (null? l)
			nil
			(cons (f (car l)) (map f (cdr l))))))

; Filter
(define filter
	(lambda (p l)
		(if (null? l)
			nil
			(if (p (car l))
				(cons (car l) (filter p (cdr l)))
				(filter p (cdr l))))))

; Folds
(define fold-right
	(lambda (f a l)
		(if (null? l)
			a
			(f (car l) (fold-right f a (cdr l))))))
(define fold-left
	(lambda (f a xs)
		(if (null? xs)
			a
			(fold-left f (f a (car xs)) (cdr xs)))))

; char functions
(define numeric-char? (lambda (ch) (if (and (char? ch) (<= 48 ch 57)) #t nil)))
(define digit->number (lambda (d) (if (and (char? d) (<= 48 d 57)) (- d 48) nil)))

; length functions
(define length (lambda (l) (if (null? l) 0 (+ 1 (length (cdr l))))))
(define string-length (lambda (s) (length (string->list s))))

; More generic comparision
(define eq?
	(lambda (a b)
		(cond
			((string? a) (if (string? b) (string=? a b) nil))
			((char? a) (if (char? b) (= a b) nil))
			(#t (= a b)))))
"ascension has successfully loaded"
