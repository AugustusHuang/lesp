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

;;;; Date object.
(in-package :lesp-builtin)

(defclass -date-prototype (-object-prototype)
  ((-prototype :initform '-object-prototype)
   ;; -DATE-VALUE could be :NAN if we try to set :INFINITY as a time.
   (-date-value :type (or timestamp keyword) :initarg :-date-value)
   (constructor :initform (make-property :value '-date) :allocation :class)
   (properties
    :initform
    (append (fetch-properties (find-class '-object-prototype))
	    '(()))))
  (:documentation "Date prototype, provides inherited properties."))

(defun -date-1 (year month &optional date hours minutes seconds ms)
  (let ((y (slot-value (-to-number year) '-number-data))
	(m (slot-value (-to-number month) '-number-data))
	(dt (if date (slot-value (-to-number date) '-number-data) 1))
	(h (if hours (slot-value (-to-number hours) '-number-data) 0))
	(min (if minutes (slot-value (-to-number minutes) '-number-data) 0))
	(s (if seconds (slot-value (-to-number seconds) '-number-data) 0))
	(milli (if ms (slot-value (-to-number ms) '-number-data) 0)))
    (let ((y-int (slot-value (-to-integer year) '-number-data))
	  (yr 0))
      (if (and (not (eql y :nan))
	       (<= 0 y-int 99))
	  (setf yr (+ 1900 y-int))
	  (setf yr y))
      (make-instance '-date-proto
		     :-date-value (encode-timestamp
				   (* milli 1000) s min h dt m yr)))))

(defun -date-0 (&optional value)
  (if value
      (if (eql (type-of value) '-date-proto)
	  value
	  (let ((v (-to-primitive) value))
	    (if (eql (-type v) 'string-type)
		(make-instance '-date-proto
			       :-date-value (unix-to-timestamp
					     (floor (!parse v) 1000)))
		(make-instance '-date-proto
			       :-date-value (unix-to-timestamp
					     (-to-number v))))))
      (make-instance '-date-proto :-date-value (now))))

;;; XXX: Use library instead if we want to be portable.
(defun %now ()
  (multiple-value-bind (sec usec) (sb-ext:get-time-of-day)
    (+ (* sec 1000) (floor usec 1000))))

;;; Unrecognizable strings or dates containing illegal element values in the
;;; format string shall cause this function to return :NAN. -- ECMA-262.
(defun %parse (string)
  (let ((str (slot-value (-to-string string) '-string-data)))
    ))

(defun !utc (&optional year month date hours minutes seconds ms)
  (let ((y (if year (slot-value (-to-number year) '-number-data) 1970))
	(yr 0)
	(m (if month (slot-value (-to-number month) '-number-data) 1))
	(dt (if date (slot-value (-to-number date) '-number-data) 1))
	(h (if hours (slot-value (-to-number hours) '-number-data) 0))
	(min (if minutes (slot-value (-to-number minutes) '-number-data) 0))
	(s (if seconds (slot-value (-to-number seconds) '-number-data) 0))
	(milli (if ms (slot-value (-to-number ms) '-number-data) 0)))
    (when (not (eql y :nan))
      (let ((int-y (slot-value (-to-integer year) '-number-data)))
	(if (<= 0 int-y 99)
	    (setf yr (+ 1900 int-y))
	    (setf yr y))))
    ;; Here the time is UTC, so do nothing on top of it.
    (!number (* 1000 (timestamp-to-unix (encode-timestamp
					 (* 1000000 milli) s min h dt m yr))))))

(defmethod get-date ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (multiple-value-bind
	  (ns ss mm hh day month year day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts)
      (!number day))))

(defmethod get-day ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (multiple-value-bind
	  (ns ss mm hh day month year day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts)
      (!number day-of-weak))))

(defmethod get-full-year ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (multiple-value-bind
	  (ns ss mm hh day month year day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts)
      (!number year))))

(defmethod get-hours ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (multiple-value-bind
	  (ns ss mm hh day month year day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts)
      (!number hh))))

(defmethod get-milliseconds ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (multiple-value-bind
	  (ns ss mm hh day month year day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts)
      (!number (floor ns 1000000)))))

(defmethod get-minutes ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (multiple-value-bind
	  (ns ss mm hh day month year day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts)
      (!number mm))))

(defmethod get-month ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (multiple-value-bind
	  (ns ss mm hh day month year day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts)
      (!number month))))

(defmethod get-seconds ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (multiple-value-bind
	  (ns ss mm hh day month year day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts)
      (!number ss))))

(defmethod get-time ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (!number (* 1000 (timestamp-to-unix ts)))))

(defmethod get-timezone-offset ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (multiple-value-bind
	  (ns ss mm hh day month year day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts)
      (!number timezone-offset))))

(defmethod get-utc-date ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (multiple-value-bind
	  (ns ss mm hh day month year day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts :timezone +utc-zone+)
      (!number day))))

(defmethod get-utc-day ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (multiple-value-bind
	  (ns ss mm hh day month year day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts :timezone +utc-zone+)
      (!number day-of-weak))))

(defmethod get-utc-full-year ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (multiple-value-bind
	  (ns ss mm hh day month year day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts :timezone +utc-zone+)
      (!number year))))

(defmethod get-utc-hours ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (multiple-value-bind
	  (ns ss mm hh day month year day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts :timezone +utc-zone+)
      (!number hh))))

(defmethod get-utc-milliseconds ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (multiple-value-bind
	  (ns ss mm hh day month year day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts :timezone +utc-zone+)
      (!number (* ns 1000000)))))

(defmethod get-utc-minutes ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (multiple-value-bind
	  (ns ss mm hh day month year day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts :timezone +utc-zone+)
      (!number mm))))

(defmethod get-utc-month ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (multiple-value-bind
	  (ns ss mm hh day month year day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts :timezone +utc-zone+)
      (!number month))))

(defmethod get-utc-seconds ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from get-date *number-nan*))
    (multiple-value-bind
	  (ns ss mm hh day month year day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts :timezone +utc-zone+)
      (!number ss))))

(defmethod set-date ((this -date-prototype) date)
  (let ((ts (slot-value this '-date-value))
	(dt (slot-value (-to-number date) '-number-data)))
    (when (eql dt :nan)
      (error "Reference error."))
    (when (or (eql dt :infinity) (eql dt :-infinity))
      (setf (slot-value this '-date-value :nan))
      (return-from set-date *number-nan*))
    (setf (slot-value this '-date-value)
	  (adjust-timestamp! ts (offset :day date)))
    (!number (* 1000 (timestamp-to-unix ts)))))

(defmethod set-full-year ((this -date-prototype) year &optional month date)
  (let ((ts (slot-value this '-date-value))
	(y (slot-value (-to-number year) '-number-data)))
    (multiple-value-bind
	  (ns ss mm hh dd mon yy day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts)
      (let ((m (if month (slot-value (-to-number month) '-number-data) mon))
	    (dt (if date (slot-value (-to-number date) '-number-data) dd)))
	(when (or (eql y :nan) (eql m :nan) (eql dt :nan))
	  (error "Reference error."))
	(when (or (eql y :infinity) (eql y :-infinity) (eql m :infinity)
		  (eql m :-infinity) (eql dt :infinity) (eql dt :-infinity))
	  (setf (slot-value this '-date-value :nan))
	  (return-from set-full-year *number-nan*))
	(setf (slot-value this '-date-value)
	      (adjust-timestamp! ts (offset :day dt :month mon :year y)))
	(!number (* 1000 (timestamp-to-unix ts)))))))

(defmethod set-hours ((this -date-prototype) hour &optional min sec ms)
  (let* ((ts (slot-value this '-date-value))
	 (h (slot-value (-to-number hour) '-number-data)))
    (multiple-value-bind
	  (ns ss mm hh dd mon yy day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts)
      (let* ((m (if min (slot-value (-to-number min) '-number-data) mm))
	     (s (if sec (slot-value (-to-number sec) '-number-data) ss))
	     ;; Of course MILLI /= NS, only a trick.
	     (milli (if ms (slot-value (-to-number ms) '-number-data) ns))
	     (nano (if (eql milli :nan)
		       :nan
		       (if (or (eql milli :infinity) (eql milli :-infinity))
			   :infinity milli))))
	(when (or (eql h :nan) (eql m :nan) (eql s :nan) (eql nano :nan))
	  (error "Reference error."))
	(when (or (eql h :infinity) (eql h :-infinity) (eql m :infinity)
		  (eql m :-infinity) (eql s :infinity) (eql s :-infinity)
		  (eql nano :infinity))
	  (setf (slot-value this '-date-value :nan))
	  (return-from set-hours *number-nan*))
	(setf (slot-value this '-date-value)
	      (adjust-timestamp! ts (offset :hour h :minute m :sec s :nsec nano)))
	(!number (* 1000 (timestamp-to-unix ts)))))))

(defmethod set-milliseconds ((this -date-prototype) ms)
  (let ((ts (slot-value this '-date-value))
	(milli (slot-value (-to-number ms) '-number-data)))
    (when (or (eql milli :infinity) (eql milli :-infinity))
      (setf (slot-value this '-date-value :nan))
      (return-from set-milliseconds *number-nan*))
    (when (eql milli :nan)
      (error "Reference error."))
    (setf (slot-value this '-date-value)
	  (adjust-timestamp! ts (offset :nsec (* milli 1000000))))
    (!number (* 1000 (timestamp-to-unix ts)))))

(defmethod set-minutes ((this -date-prototype) min &optional sec ms)
  (let ((ts (slot-value this '-date-value))
	(m (slot-value (-to-number min) '-number-data)))
    (multiple-value-bind
	  (ns ss mm hh dd mon yy day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts)
      (let* ((s (if sec (slot-value (-to-number sec) '-number-data) ss))
	     (milli (if ms (slot-value (-to-number ms) '-number-data) ns))
	     (nano (if (eql milli :nan)
		       :nan
		       (if (or (eql milli :infinity) (eql milli :-infinity))
			   :infinity milli))))
	(when (or (eql m :nan) (eql s :nan) (eql nano :nan))
	  (error "Reference error."))
	(when (or (eql m :infinity) (eql m :-infinity) (eql s :infinity)
		  (eql s :-infinity) (eql nano :infinity))
	  (setf (slot-value this '-date-value :nan))
	  (return-from set-minutes *number-nan*))
	(setf (slot-value this '-date-value)
	      (adjust-timestamp! ts (offset :minute m :sec s :nsec nano)))
	(!number (* 1000 (timestamp-to-unix ts)))))))

(defmethod set-month ((this -date-prototype) month &optional date)
  (let ((ts (slot-value this '-date-value))
	(m (slot-value (-to-number month) '-number-data)))
    (multiple-value-bind
	  (ns ss mm hh dd mon yy day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts)
      (let ((dt (if date (slot-value (-to-number date) '-number-data) dd)))
	(when (or (eql m :nan) (eql dt :nan))
	  (error "Reference error."))
	(when (or (eql m :infinity) (eql m :-infinity)
		  (eql dt :infinity) (eql dt :-infinity))
	  (setf (slot-value this '-date-value :nan))
	  (return-from set-month *number-nan*))
	(setf (slot-value this '-date-value)
	      (adjust-timestamp! ts (offset :month m :day dt)))
	(!number (* 1000 (timestamp-to-unix ts)))))))

(defmethod set-seconds ((this -date-prototype) sec &optional ms)
  (let ((ts (slot-value this '-date-value))
	(s (slot-value (-to-number sec) '-number-data)))
    (multiple-value-bind
	  (ns ss mm hh dd mon yy day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts)
      (let* ((milli (if ms (slot-value (-to-number ms) '-number-data) ns))
	     (nano (if (eql milli :nan)
		       :nan
		       (if (or (eql milli :infinity) (eql milli :-infinity))
			   :infinity milli))))
	(when (or (eql s :nan) (eql nano :nan))
	  (error "Reference error."))
	(when (or (eql s :infinity) (eql s :-infinity) (eql nano :infinity))
	  (setf (slot-value this '-date-value :nan))
	  (return-from set-seconds *number-nan*))
	(setf (slot-value this '-date-value)
	      (adjust-timestamp! ts (offset :sec s :nsec nano)))
	(!number (* 1000 (timestamp-to-unix ts)))))))

(defmethod set-time ((this -date-prototype) time)
  (let* ((tm (slot-value (-to-number time) '-number-data))
	 (nano (if (eql tm :nan)
		   :nan
		   (if (or (eql tm :infinity) (eql tm :-infinity))
		       :infinity (* 1000000 (mod tm 1000))))))
    (when (eql nano :infinity)
      (setf (slot-value this '-date-value) :nan)
      (return-from set-time *number-nan*))
    (when (eql nano :nan)
      (error "Reference error."))
    (setf (slot-value this '-date-value) (unix-to-timestamp tm :nsec nano))
    (!number tm)))

(defmethod set-utc-date ((this -date-prototype) date)
  (let ((ts (slot-value this '-date-value))
	(dt (slot-value (-to-number date) '-number-data)))
    (multiple-value-bind
	  (ns ss mm hh dd mon yy day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts :timezone +utc-zone+)
      (when (or (eql dt :infinity) (eql dt :-infinity))
	(setf (slot-value this '-date-value) :nan)
	(return-from set-utc-date *number-nan*))
      (when (eql dt :nan)
	(error "Reference error."))
      (setf (slot-value this '-date-value)
	    (adjust-timestamp! ts (offset :day date)))
      (!number (* 1000 (timestamp-to-unix ts))))))

(defmethod set-utc-full-year ((this -date-prototype) year &optional month date)
  (let ((ts (slot-value this '-date-value))
	(y (slot-value (-to-number year) '-number-data)))
    (multiple-value-bind
	  (ns ss mm hh dd mon yy day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts :timezone +utc-zone+)
      (let ((m (if month (slot-value (-to-number month) '-number-data) mon))
	    (dt (if date (slot-value (-to-number date) '-number-data) dd)))
	(when (or (eql y :infinity) (eql y :-infinity) (eql m :infinity)
		  (eql m :-infinity) (eql dt :infinity) (eql dt :-infinity))
	  (setf (slot-value this '-date-value) :nan)
	  (return-from set-utc-full-year *number-nan*))
	(when (or (eql y :nan) (eql m :nan) (eql dt :nan))
	  (error "Reference error."))
	(setf (slot-value this '-date-value)
	      (adjust-timestamp! ts (offset :year y :month m :day dt)))
	(!number (* 1000 (timestamp-to-unix ts)))))))

(defmethod set-utc-hours ((this -date-prototype) hour &optional min sec ms)
  (let ((ts (slot-value this '-date-value))
	(h (slot-value (-to-number hour) '-number-data)))
    (multiple-value-bind
	  (ns ss mm hh dd mon yy day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts :timezone +utc-zone+)
      (let* ((m (if min (slot-value (-to-number min) '-number-data) mm))
	     (s (if sec (slot-value (-to-number sec) '-number-data) ss))
	     (milli (if ms (slot-value (-to-number ms) '-number-data) ns))
	     (nano (if (eql milli :nan)
		       :nan
		       (if (or (eql milli :infinity) (eql milli :-infinity))
			   :infinity ns))))
	(when (or (eql h :infinity) (eql h :-infinity) (eql m :infinity)
		  (eql m :-infinity) (eql s :infinity) (eql s :-infinity)
		  (eql nano :infinity))
	  (setf (slot-value this '-date-value) :nan)
	  (return-from set-utc-hours *number-nan*))
	(when (or (eql h :nan) (eql m :nan) (eql s :nan) (eql nano :nan))
	  (error "Reference error."))
	(setf (slot-value this '-date-value)
	      (adjust-timestamp! ts (offset :hour h :minute m :sec s :nsec nano)))
	(!number (* 1000 (timestamp-to-unix ts)))))))

(defmethod set-utc-milliseconds ((this -date-prototype) ms)
  (let ((ts (slot-value this '-date-value))
	(milli (slot-value (-to-number ms) '-number-data)))
    (when (or (eql milli :infinity) (eql milli :-infinity))
      (setf (slot-value this '-date-value) :nan)
      (return-from set-utc-milliseconds *number-nan*))
    (setf (slot-value this '-date-value)
	  (adjust-timestamp! ts (offset :nsec (* milli 1000000))))
    (!number (* 1000 (timestamp-to-unix ts)))))

(defmethod set-utc-minutes ((this -date-prototype) min &optional sec ms)
  (let ((ts (slot-value this '-date-value))
	(m (slot-value (-to-number min) '-number-data)))
    (multiple-value-bind
	  (ns ss mm hh dd mon yy day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts :timezone +utc-zone+)
      (let* ((s (if sec (slot-value (-to-number sec) '-number-data) ss))
	     (milli (if ms (slot-value (-to-number ms) '-number-data) ns))
	     (nano (if (eql ms :nan)
		       :nan
		       (if (or (eql ms :infinity) (eql ms :-infinity))
			   :infinity ns))))
	(when (or (eql m :infinity) (eql m :-infinity) (eql s :infinity)
		  (eql s :-infinity) (eql nano :infinity))
	  (setf (slot-value this '-date-value) :nan)
	  (return-from set-utc-minutes *number-nan*))
	(when (or (eql m :nan) (eql s :nan) (eql nano :nan))
	  (error "Reference error."))
	(setf (slot-value this '-date-value)
	      (adjust-timestamp! ts (offset :minute m :sec s :nsec nano)))
	(!number (* 1000 (timestamp-to-unix ts)))))))

(defmethod set-utc-month ((this -date-prototype) month &optional date)
  (let ((tm (slot-value this '-date-value))
	(m (slot-value (-to-number month) '-number-data)))
    (multiple-value-bind
	  (ns ss mm hh dd mon yy day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts :timezone +utc-zone+)
      (let ((dt (if date (slot-value (-to-number date) '-number-data dd))))
	(when (or (eql m :infinity) (eql m :-infinity) (eql dt :infinity)
		  (eql dt :-infinity))
	  (setf (slot-value this '-date-value) :nan)
	  (return-from set-utc-month *number-nan*))
	(when (or (eql m :nan) (eql dt :nan))
	  (error "Reference error."))
	(setf (slot-value this '-date-value)
	      (adjust-timestamp! ts (offset :month m :day dt)))
	(!number (* 1000 (timestamp-to-unix ts)))))))

(defmethod set-utc-seconds ((this -date-prototype) sec &optional ms)
  (let ((tm (slot-value this '-date-value))
	(s (slot-value (-to-number sec) '-number-data)))
    (multiple-value-bind
	  (ns ss mm hh dd mon yy day-of-weak daylight-saving-time-p timezone-offset timezone-abbr) (decode-timestamp ts :timezone +utc-zone+)
      (let* ((milli (if ms (slot-value (-to-number ms) '-number-data) ns))
	     (nano (if (eql ms :nan)
		       :nan
		       (if (or (eql ms :infinity) (eql ms :-infinity))
			   :infinity ns))))
	(when (or (eql s :infinity) (eql s :-infinity) (eql nano :infinity))
	  (setf (slot-value this '-date-value) :nan)
	  (return-from set-utc-seconds *number-nan*))
	(when (or (eql s :nan) (eql nano :nan))
	  (error "Reference error."))
	(setf (slot-value this '-date-value)
	      (adjust-timestamp! ts (offset :sec s :nsec nano)))
	(!number (* 1000 (timestamp-to-unix ts)))))))

(defmethod to-date-string ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from to-date-string (!string "Invalid Date")))
    (!string (format-rfc1123-timestring nil ts))))

(defmethod to-iso-string ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from to-date-string (!string "Invalid Date")))
    (!string (format-timestring nil ts))))

;;; How to implement this?
(defmethod to-json ((this -date-prototype) key)
  )

(defmethod to-locale-date-string ((this -date-prototype))
  )

(defmethod to-locale-string ((this -date-prototype))
  )

(defmethod to-locale-time-string ((this -date-prototype))
  )

;;; Also implementation dependent.
(defmethod to-string ((this -date-prototype))
  (to-date-string this))

(defmethod to-time-string ((this -date-prototype))
  (to-date-string this))

(defmethod to-utc-string ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from to-utc-string (!string "Invalid Date")))
    (!string (format-rfc1123-timestring nil ts :timezone +utc-zone+))))

(defmethod value-of ((this -date-prototype))
  (let ((ts (slot-value this '-date-value)))
    (when (eql ts :nan)
      (return-from value-of *number-nan*))
    (let ((nano (nsec-of ts)))
      (!number (+ (* 1000 (timestamp-to-unix ts)) (floor nano 1000000))))))

(defmethod to-primitive ((this -date-prototype) hint)
  (case hint
    ((default string)
     (-to-primitive this 'string))
    ('number
     (-to-primitive this 'number))
    (t
     (error "Type error."))))
