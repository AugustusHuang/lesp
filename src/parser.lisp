;;;; The MIT License (MIT)

;;;; Copyright (c) 2015 Huang Xuxing

;;;; Permission is hereby granted, free of charge, to any person obtaining
;;;; a copy of this software and associated documentation files
;;;; (the "Software"), to deal in the Software without restriction,
;;;; including without limitation the rights to use, copy, modify, merge,
;;;; publish, distribute, sublicense, and/or sell copies of the Software,
;;;; and to permit persons to whom the Software is furnished to do so,
;;;; subject to the following conditions:

;;;; The above copyright notice and this permission notice shall be included
;;;; in all copies or substantial portions of the Software.

;;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;;;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;;;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
;;;; THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;;;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
;;;; ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
;;;; OTHER DEALINGS IN THE SOFTWARE.

;;;; Copyright (c) Marijn Haverbeke, marijnh@gmail.com

;;;; This software is provided 'as-is', without any express or implied
;;;; warranty. In no event will the authors be held liable for any
;;;; damages arising from the use of this software.

;;;; Permission is granted to anyone to use this software for any
;;;; purpose, including commercial applications, and to alter it and
;;;; redistribute it freely, subject to the following restrictions:

;;;; 1. The origin of this software must not be misrepresented; you must
;;;;    not claim that you wrote the original software. If you use this
;;;;    software in a product, an acknowledgment in the product
;;;;    documentation would be appreciated but is not required.

;;;; 2. Altered source versions must be plainly marked as such, and must
;;;;    not be misrepresented as being the original software.

;;;; 3. This notice may not be removed or altered from any source
;;;;    distribution.

;;;; Parser package.
(in-package :lesp-parser)

;;; FIXME: Change Javascript from 3rd version to 6th version. Some new
;;; reserved keywords will be added, and maybe some change in the source.
(defparameter +unary-prefix+ '(:typeof :void :delete :-- :++ :! :~ :- :+ :...))
(defparameter +unary-postfix+ '(:-- :++))
(defparameter +assignment+
  (let ((assign (make-hash-table)))
    (dolist (op '(:+= :-= :/= :*= :%= :>>= :<<= :>>>= :|\|=| :^= :&=))
      (setf (gethash op assign)
	    (intern (subseq (string op) 0 (1- (length (string op)))) :keyword)))
    (setf (gethash := assign) t)
    assign))

(defparameter +precedence+
  (let ((precs (make-hash-table)))
    ;; The => arrow function operator and ... spread operator are the last.
    ;; The . property operator is the first.
    (loop for ops in '((:...) (:=>) (:|\|\||) (:&&) (:|\||) (:^) (:&)
		       (:== :=== :!= :!==) (:< :> :<= :>= :in :instanceof)
		       (:>> :<< :>>>) (:+ :-) (:* :/ :%))
       for n from 1
       do (dolist (op ops) (setf (gethash op precs) n)))
    precs))

(defparameter *in-function* nil)
(defparameter *label-scope* nil)
(defmacro with-label-scope (type label &body body)
  `(let ((*label-scope* (cons (cons ,type ,label) *label-scope*))) ,@body))

(define-condition parser-error (general-error)
  ((char :initarg :char
	 :initform lesp-parser:*char* :reader parser-error-char)
   (line :initarg :line
	 :initform lesp-parser:*line* :reader parser-error-line))
  (:documentation "Lesp parser error."))

(defmethod print-object ((err parser-error) stream)
  (call-next-method)
  (format stream ":~A:~D:"
	  (parser-error-char err)
	  (parser-error-line err)))

(defun parser-error (control &rest args)
  (error 'parser-error :format-control control :format-arguments args))

;;; Only version 6 is supported!
(defun parse-js (input &key strict-semicolons reserved-words)
  (let ((*check-for-reserved-words* reserved-words)
        (*line* 0)
        (*char* 0)
        (*position* 0))
    (if (stringp input)
        (with-input-from-string (in input) (parse-js* in strict-semicolons))
        (parse-js* input strict-semicolons))))

;;; TODO: Problems when parsing ES6 now:
;;; 1. New object representation.
;;; 2. Object and array as arguments.
;;; 3. Variable definition in class, though not encouraged.
;;; 4. Get and set in class.
;;; 5. Spread operator in function call.

(defun/defs parse-js* (stream &optional strict-semicolons)
  (def input (if (functionp stream) stream (lex-js stream)))
  (def token (funcall input))
  (def peeked nil)

  (def peek ()
    (or peeked (setf peeked (funcall input))))
  
  (def next ()
    (if peeked
        (setf token peeked peeked nil)
        (setf token (funcall input)))
    token)
  
  (def skip (n)
    (dotimes (i n) (next)))

  (def token-error (token control &rest args)
    (let ((*line* (token-line token)) (*char* (token-char token)))
      (apply #'parser-error control args)))
  
  (def error* (control &rest args)
    (apply #'token-error token control args))
  
  (def unexpected (token)
    (token-error token "Unexpected token '~A'" (token-id token)))

  ;; If the token is what we want, step forward, or signal an error.
  (def expect-token (type val)
    (if (tokenp token type val)
        (next)
        (error* "Unexpected token '~A', expected '~A'"
		(token-id token) val)))
  
  (def expect (punc)
    (expect-token :punc punc))
  
  (def expect-key (keyword)
    (expect-token :keyword keyword))
  
  (def can-insert-semicolon ()
    (and (not strict-semicolons)
         (or (token-newline-before token)
             (token-type-p token :eof)
             (tokenp token :punc #\}))))
  
  (def semicolonp () (tokenp token :punc #\;))
  
  (def semicolon ()
    (cond ((semicolonp) (next))
          ((not (can-insert-semicolon)) (unexpected token))))

  (def as (type &rest args)
    (cons type args))

  (def parenthesised ()
    (expect #\() (prog1 (expression) (expect #\))))

  (def statement (&optional label)
    ;; if expecting a statement and found a slash as operator,
    ;; it must be a literal regexp.
    (when (and (eq (token-type token) :operator)
               (eq (token-value token) :/))
      (setf peeked nil
            token (funcall input t)))
    (cond ((or (eq (token-type token) :num)
	       (eq (token-type token) :string)
	       (eq (token-type token) :regexp)
	       (eq (token-type token) :operator)
	       (eq (token-type token) :atom)
	       (eq (token-type token) :template))
	   (simple-statement))
	  ((eq (token-type token) :name)
	   (if (tokenp (peek) :punc #\:)
	       (let ((label (prog1 (token-value token) (skip 2))))
		 (as :label label
		     (with-label-scope :label label (statement label))))
	       (simple-statement)))
	  ((or (tokenp token :keyword :this)
	       (tokenp token :keyword :super))
	   (simple-statement))
	  ((eq (token-type token) :punc)
	   (case (token-value token)
	     (#\{ (next) (block*))
	     ((#\[ #\() (simple-statement))
	     (#\; (next) (as :block ()))
	     (t (unexpected token))))
	  ((eq (token-type token) :keyword)
	   ;; Add const and let in ECMA version 6.
	   ;; NOTE: Though now we handle strict-mode keywords as ordinary
	   ;; keywords so that they can't be variable names,
	   ;; we don't handle them explicitly for now.
	   ;; --- Augustus, 24 Aug 2015.
	   (case (prog1 (token-value token) (next))
	     (:break (break/cont :break))
	     (:class (class*))
	     (:const (prog1 (const*) (semicolon)))
	     (:continue (break/cont :continue))
	     (:debugger (semicolon) (as :debugger))
	     (:do (let ((body (with-label-scope :loop label (statement))))
		    (expect-key :while)
		    (as :do (parenthesised) body)))
	     (:export (export*))
	     (:for (for* label))
	     (:function (function* t))
	     (:if (if*))
	     (:import (import*))
	     (:let (prog1 (js-let) (semicolon)))
	     (:return (unless *in-function*
			(error* "'return' outside of function"))
		      (as :return
			  (cond ((semicolonp) (next) nil)
				((can-insert-semicolon) nil)
				(t (prog1 (expression) (semicolon))))))
	     (:super (super*))
	     (:switch (let ((val (parenthesised))
			    (cases nil))
			(with-label-scope :switch label
			  (expect #\{)
			  (loop :until (tokenp token :punc #\}) :do
			     (case (token-value token)
			       (:case (next)
				 (push (cons (prog1 (expression) (expect #\:)) nil) cases))
			       (:default (next) (expect #\:) (push (cons nil nil) cases))
			       (t (unless cases (unexpected token))
				  (push (statement) (cdr (car cases))))))
			  (next)
			  (as :switch val (loop for case in (nreverse cases)
					     collect (cons (car case)
							   (nreverse (cdr case))))))))
	     (:throw (let ((ex (expression))) (semicolon) (as :throw ex)))
	     (:this (this*))
	     (:try (try*))
	     (:var (prog1 (var*) (semicolon)))
	     (:while (as :while (parenthesised)
			 (with-label-scope :loop label (statement))))
	     (:with (as :with (parenthesised) (statement)))
	     (t (unexpected token))))
	  (t (unexpected token))))

  (def simple-statement ()
    (let ((exp (expression)))
      (semicolon)
      (as :stat exp)))

  (def break/cont (type)
    (as type (cond ((or (and (semicolonp) (next)) (can-insert-semicolon))
                    (unless (loop for (ltype) in *label-scope* do
				 (when (or (eq ltype :loop)
					   (and (eq type :break)
						(eq ltype :switch)))
				   (return t)))
                      (error* "'~A' not inside a loop or switch" type))
                    nil)
                   ((token-type-p token :name)
                    (let ((name (token-value token)))
                      (ecase type
                        (:break
			 (unless (some (lambda (lb) (equal (cdr lb) name)) *label-scope*)
			   (error* "Labeled 'break' without matching labeled statement")))
                        (:continue
			 (unless (find (cons :loop name) *label-scope* :test #'equal)
			   (error* "Labeled 'continue' without matching labeled loop"))))
                      (next) (semicolon)
                      name)))))

  (def block* ()
    (prog1 (as :block (loop until (tokenp token :punc #\})
			 collect (statement)))
      (next)))

  (def for-in (label init lhs)
    (let ((obj (progn (next) (expression))))
      (expect #\))
      (as :for-in init lhs obj (with-label-scope :loop label (statement)))))

  (def regular-for (label init)
    (expect #\;)
    (let ((test (prog1 (unless (semicolonp) (expression)) (expect #\;)))
          (step (if (tokenp token :punc #\)) nil (expression))))
      (expect #\))
      (as :for init test step (with-label-scope :loop label (statement)))))

  ;; For-of loop newly defined in ECMA 6, should used as
  ;; for (let i of ITERATOR-FUNCTION) or for (var i of XXX).
  (def for-of (label init scope)
    (let ((obj (progn (next) (expression))))
      (expect #\))
      (as :for-of init scope obj (with-label-scope :loop label (statement)))))
  
  ;; Also add for-of loop here.
  (def for* (label)
    (expect #\()
    (cond ((semicolonp) (regular-for label nil))
          ((tokenp token :keyword :var)
           (let* ((var (progn (next) (var* t)))
                  (defs (second var)))
	     (if (and (not (cdr defs))
		      (tokenp token :operator :in))
		 (for-in label var (as :name (caar defs)))
		 (if (and (not (cdr defs))
			  (tokenp token :operator :of))
		     (for-of label var (as :name (caar defs)))
		     (regular-for label var)))))
	  ((tokenp token :keyword :let)
	   (let* ((let-decl (progn (next) (js-let t)))
		  (defs (second let-decl)))
	     (if (and (not (cdr defs))
		      (tokenp token :operator :in))
		 (for-in label let-decl (as :name (caar defs)))
		 (if (and (not (cdr defs))
			  (tokenp token :operator :of))
		     (for-of label let-decl (as :name (caar defs)))
		     (regular-for label let-decl)))))
	  ;; Do we need OF here?
          (t (let ((init (expression t t)))
               (if (tokenp token :operator :in)
                   (for-in label nil init)
                   (regular-for label init))))))

  ;; New feature in version 6.
  ;; class XXX extends YYY {
  ;;     constructor (a, b, c, d, e) {
  ;;         super(d, e);
  ;;         this.a = a;
  ;;         this.b = b;
  ;;         this.c = c;
  ;;     }
  ;;     static method() {
  ;;         return true;
  ;;     }
  ;;     method() {
  ;;     }
  ;; }
  (def class* ()
    (let ((superclass nil))
      (with-defs
	(def name (and (token-type-p token :name)
		       (prog1 (token-value token) (next))))
	(when (not name) (unexpected token))
	;; Superclass, make extends optional...
	(when (tokenp token :keyword :extends)
	  (progn (next) (if (token-type-p token :name)
			    (setf superclass (token-value token))
			    (unexpected token))
		 (next)))
	(expect #\{)
	(def body (let ((*label-scope* ()))
		    ;; How about var, let and const?
		    ;; Class definition only contains functions' definitions.
		    (loop until (tokenp token :punc #\})
		       collect (prog1
				   (if (tokenp token :keyword :static)
				       (static-function* t)
				       (function* t))))))
	(next)
	(if superclass
	    (as :class name :extends superclass body)
	    (as :class name body)))))

  (def static-function* (statement)
    (progn
      (next)
      (if (token-type-p token :name)
	  (as :static (function* statement))
	  (unexpected token))))
  
  (def function* (statement)
    (with-defs
	(def name (and (token-type-p token :name)
		       (prog1 (token-value token) (next))))
      (when (and statement (not name)) (unexpected token))
      (expect #\()
      ;; NOTE: Spread operator looks the same, but it only appear when
      ;; the function is called. so it won't be hard to tell them apart.
      (def argnames (loop for first = t then nil
		       until (tokenp token :punc #\))
		       unless first do (expect #\,)
		       unless (or (token-type-p token :name)
				  (tokenp token :operator :...)
				  (tokenp token :punc #\[)
				  (tokenp token :punc #\{))
		       do (unexpected token)
		       ;; Return "a" if normal argument,
		       ;; return (:ARRAY xxx) or (:Object xxx) if using
		       ;; destructuring,
		       ;; return ("a" 0) if default argument with value 0,
		       ;; return (:REST args) if rest argument args,
		       ;; return (:SPREAD iterable) if in function calls.
		       collect (let ((val (token-value token))
				     (type (token-type token)))
				 (next)
				 (cond ((and (eq type :name)
					     (tokenp token :punc #\,))
					val)
				       ((and (eq type :name)
					     (tokenp token :punc #\)))
					val)
				       ((and (eq type :name)
					     (tokenp token :operator :=))
					(list val (prog2 (next)
						      (token-value token)
						    (next))))
				       ((and (eq type :operator)
					     statement
					     (token-type-p token :name))
					(if (tokenp (peek) :punc #\))
					    (prog1
						(list :rest (token-value token))
					      (next))
					    ;; The rest parameters should and
					    ;; only appear at the last place.
					    (unexpected token)))
				       ((and (eq type :operator)
					     (not statement))
					(if (token-type-p token :name)
					    (prog1
						(list :spread (token-value token))
					      (next))
					    (if (tokenp token :punc #\[)
						(list :spread (progn
								(next)
								(array*)))
						(unexpected token))))
				       ((eq val #\[)
					(progn (next) (array*)))
				       ((eq val #\{)
					(progn (next) (object*)))
				       (t
					(unexpected token))))))
      (next)
      (expect #\{)
      (def body (let ((*in-function* t) (*label-scope* ()))
                  (loop until (tokenp token :punc #\}) collect (statement))))
      (next)
      (as (if statement :defun :function) name argnames body)))

  (def if* ()
    (let ((condition (parenthesised))
          (body (statement))
          else)
      (when (tokenp token :keyword :else)
        (next)
        (setf else (statement)))
      (as :if condition body else)))

  (def ensure-block ()
    (expect #\{)
    (block*))

  (def try* ()
    (let ((body (ensure-block)) catch finally)
      (when (tokenp token :keyword :catch)
        (next) (expect #\()
        (unless (token-type-p token :name) (error* "Name expected"))
        (let ((name (token-value token)))
          (next) (expect #\))
          (setf catch (cons name (ensure-block)))))
      (when (tokenp token :keyword :finally)
        (next)
        (setf finally (ensure-block)))
      (as :try body catch finally)))

  ;; Merge var, const and let definitions, the only difference is the prefix.
  (def vardefs (no-in)
    (cond ((token-type-p token :name)
	   (let ((name (token-value token)) val)
	     (next)
	     (when (tokenp token :operator :=)
	       (next) (setf val (expression nil no-in)))
	     (if (tokenp token :punc #\,)
		 (progn (next) (cons (cons name val) (vardefs no-in)))
		 (list (cons name val)))))
	  ((tokenp token :punc #\[)
	   (let ((lhs (progn (next) (array*))) val)
	     (when (tokenp token :operator :=)
	       (next) (setf val (expression nil no-in)))
	     (if (tokenp token :punc #\,)
		 (progn (next) (cons (cons lhs val) (vardefs no-in)))
		 (list (cons lhs val)))))
	  ((tokenp token :punc #\{)
	   (let ((lhs (progn (next) (object*))) val)
	     (when (tokenp token :operator :=)
	       (next) (setf val (expression nil no-in)))
	     (if (tokenp token :punc #\,)
		 (progn (next) (cons (cons lhs val) (vardefs no-in)))
		 (list (cons lhs val)))))
	  (t
	   (unexpected token))))

  (def var* (&optional no-in)
    (as :var (vardefs no-in)))

  (def const* ()
    (as :const (vardefs t)))

  (def js-let (&optional no-in)
    (as :let (vardefs no-in)))

  ;; Shall we implement a export and import list,
  ;; and support modular programming in such an early stage?
  (def export* ()
    (cond ((tokenp token :keyword :default)
	   (let ((type-tok (next)))
	     (cond ((tokenp type-tok :keyword :var)
		    (as :export :default (progn (next) (var*))))
		   ((tokenp type-tok :keyword :let)
		    (as :export :default (progn (next) (js-let))))
		   ((tokenp type-tok :keyword :const)
		    (as :export :default (progn (next) (const*))))
		   ((tokenp type-tok :keyword :function)
		    (as :export :default
			;; When default export a function and a class,
			;; it will be an anonymous declaration.
			(progn (next) (function* t))))
		   ((tokenp type-tok :keyword :class)
		    (as :export :default (progn (next) (class*))))
		   (t (unexpected type-tok)))))
	  ((tokenp token :punc #\{)
	   ;; export { XXX as XXX, XXX as XXX };, export { XXX, XXX };
	   ;; or export { XXX as XXX } from XXX;.
	   (let ((lst (xport-as-list #\} nil t)))
	     (next)
	     (if (semicolonp)
		 (prog1
		     (as :export lst)
		   (next))
		 (if (token-type-p token :string)
		     (prog1
			 (as :export lst (token-value token))
		       (next))
		     (unexpected token)))))
	  ((tokenp token :operator :*)
	   ;; export * from XXX;.
	   (next)
	   (expect-key :from)
	   (let ((module (prog1 (if (not (token-type-p token :string))
				    (unexpected token)
				    (token-value token))
			   (next))))
	     (if (semicolonp)
		 (prog1
		     (as :export :all :from module)
		   (next)))))
	  ((tokenp token :keyword :var)
	   (as :export (progn (next) (var*))))
	  ((tokenp token :keyword :let)
	   (as :export (progn (next) (js-let))))
	  ((tokenp token :keyword :const)
	   (as :export (progn (next) (const*))))
	  ((tokenp token :keyword :function)
	   (as :export (progn (next) (function* t))))
	  ((tokenp token :keyword :class)
	   (as :export (progn (next) (class*))))
	  (t
	   (unexpected token))))
  
  (def import* ()
    ;; Can be import XXX from XXX;, import * as XXX from XXX;,
    ;; or import { XXX, XXX } from XXX;.
    (cond ((tokenp token :operator :*)
	   (next)
	   (expect-key :as)
	   (let ((binding (if (not (token-type-p token :name))
			      (unexpected token)
			      (prog1 (token-value token) (next)))))
	     (expect-key :from)
	     (let ((module (prog1 (if (not (token-type-p token :string))
				      (unexpected token)
				      (token-value token))
			     (next))))
	       (if (semicolonp)
		   (prog1
		       (as :import (as (as :all :as binding) :from module))
		     (next))))))
	  ((tokenp token :punc #\{)
	   (let ((imports (xport-as-list #\} nil t)))
	     (next)
	     (expect-key :from)
	     (let ((module (prog1 (if (not (token-type-p token :string))
				      (unexpected token)
				      (token-value token))
			     (next))))
	       (if (semicolonp)
		   (prog1
		       (as :import imports :from module)
		     (next))))))
	  ((token-type-p token :name)
	   (let ((imported (token-value token))
		 (module (progn (next) (expect-key :from)
				(prog1 (if (not (token-type-p token :string))
					   (unexpected token)
					   (token-value token))
				  (next)))))
	     (if (semicolonp)
		 (prog1
		     (as :import imported :from module)
		   (next)))))
	  (t
	   (unexpected token))))
  
  (def new* ()
    (let ((newexp (expr-atom nil)))
      (let ((args nil))
        (when (tokenp token :punc #\()
          (next) (setf args (expr-list #\))))
        (subscripts (as :new newexp args) t))))

  (def expr-atom (allow-calls)
    (cond ((tokenp token :operator :new) (next) (new*))
          ((token-type-p token :punc)
           (case (token-value token)
             (#\( (next) (subscripts (prog1 (expression) (expect #\)))
				     allow-calls))
             (#\[ (next) (subscripts (array*) allow-calls))
             (#\{ (next) (subscripts (object*) allow-calls))
             (t (unexpected token))))
          ((tokenp token :keyword :function)
           (next)
           (subscripts (function* nil) allow-calls))
	  ((or (tokenp token :keyword :this)
	       (tokenp token :keyword :super))
	   (let ((atom (token-value token)))
	     (subscripts (prog1 atom (next)) allow-calls)))
          ((member (token-type token) '(:atom :num :string
					:regexp :template :name))
           (let ((atom (if (eq (token-type token) :regexp)
                           (as :regexp
			       (car (token-value token))
			       (cdr (token-value token)))
                           (as (token-type token) (token-value token)))))
             (subscripts (prog1 atom (next)) allow-calls)))
          (t (unexpected token))))

  (def expr-list (closing &optional allow-trailing-comma allow-empty)
    (let ((elts ()))
      (loop for first = t then nil until (tokenp token :punc closing) do
	   (unless first (expect #\,))
	   (when (and allow-trailing-comma (tokenp token :punc closing))
	     (return))
	   (push (unless (and allow-empty
			      (tokenp token :punc #\,))
		   (expression nil)) elts))
      (next)
      (nreverse elts)))

  ;; Handle export/import as-list.
  (def xport-as-list (closing &optional allow-trailing-comma allow-empty)
    (let ((elts ()))
      (next)
      (loop for first = t then nil until (tokenp token :punc closing) do
	   (unless first (expect #\,))
	   (when (and allow-trailing-comma (tokenp token :punc closing))
	     (return))
	   (push (unless (and allow-empty
			      (tokenp token :punc #\,))
		   (let ((cur-tok (token-value token)))
		     (cons (prog1 cur-tok (next))
			   (if (tokenp token :punc #\,)
			       nil
			       (if (tokenp token :punc #\})
				   (progn
				     (push (list cur-tok) elts)
				     (return))
				   (cons (progn (expect-key :as) :as)
					 (prog1 (list (token-value token)) (next))))))))
		 elts))
      (nreverse elts)))
  
  (def array* ()
    (as :array (expr-list #\] t t)))

  (def object* ()
    ;; Now object property can be written as a = 0 instead of a: a = 0.
    (as :object (loop for first = t then nil
		   until (tokenp token :punc #\})
		   unless first do (expect #\,)
		   until (tokenp token :punc #\})
		   collect
		     (let ((name (as-property-name)))
		       (cond ((tokenp token :punc #\:)
			      (next) (cons name (expression nil)))
			     ;; TODO: They can also appear in class.
			     ;; It seems they are cheated as functions.
			     ((or (equal name "get") (equal name "set"))
			      (let ((name1 (as-property-name))
				    (body (progn
					    (unless (tokenp token :punc #\()
					      (unexpected token))
					    (function* nil))))
				(list* name1
				       (if (equal name "get")
					   :get
					   :set)
				       body)))
			     (t (unexpected token))))
                   finally (next))))
  
  (def as-property-name ()
    (if (member (token-type token) '(:num :string))
        (prog1 (token-value token) (next))
        (as-name)))

  (def as-name ()
    (case (token-type token)
      (:name (prog1 (token-value token) (next)))
      ((:operator :keyword :atom)
       (prog1 (string-downcase (symbol-name (token-value token))) (next)))
      (t (unexpected token))))

  (def subscripts (expr allow-calls)
    (cond ((tokenp token :punc #\.)
           (next)
           (subscripts (as :dot expr (as-name)) allow-calls))
          ((tokenp token :punc #\[)
           (next)
           (let ((sub (expression)))
             (expect #\])
             (subscripts (as :sub expr sub) allow-calls)))
          ((and (tokenp token :punc #\() allow-calls)
           (next)
           (let ((args (expr-list #\))))
             (subscripts (as :call expr args) t)))
          (t expr)))

  (def maybe-unary (allow-calls)
    (if (and (token-type-p token :operator)
	     (member (token-value token) +unary-prefix+))
        (as :unary-prefix (prog1 (token-value token) (next))
	    (maybe-unary allow-calls))
        (let ((val (expr-atom allow-calls)))
          (loop while (and (token-type-p token :operator)
			   (member (token-value token) +unary-postfix+)
			   (not (token-newline-before token))) do
             (setf val (as :unary-postfix (token-value token) val))
             (next))
          val)))

  (def expr-op (left min-prec no-in)
    (let* ((op (and (token-type-p token :operator)
		    (or (not no-in) (not (eq (token-value token) :in)))
                    (token-value token)))
           (prec (and op (gethash op +precedence+))))
      (if (and prec (> prec min-prec))
          (let ((right (progn (next) (expr-op (maybe-unary t) prec no-in))))
            (expr-op (as :binary op left right) min-prec no-in))
          left)))

  (def expr-ops (no-in)
    (expr-op (maybe-unary t) 0 no-in))

  (def maybe-conditional (no-in)
    (let ((expr (expr-ops no-in)))
      (if (tokenp token :operator :?)
          (let ((yes (progn (next) (expression nil))))
            (expect #\:)
            (as :conditional expr yes (expression nil no-in)))
          expr)))

  (def maybe-assign (no-in)
    (let ((left (maybe-conditional no-in)))
      (if (and (token-type-p token :operator)
	       (gethash (token-value token) +assignment+))
          (as :assign (gethash (token-value token) +assignment+) left
	      (progn (next) (maybe-assign no-in)))
          left)))

  (def expression (&optional (commas t) (no-in nil))
    (let ((expr (maybe-assign no-in)))
      (if (and commas (tokenp token :punc #\,))
          (as :seq expr (progn (next) (expression)))
          expr)))

  (as :lesp (loop until (token-type-p token :eof)
	       collect (statement))))

(defun parse-js-string (&rest args)
  (apply 'parse-js args))

