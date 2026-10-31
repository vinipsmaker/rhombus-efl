#lang info

(define collection 'multi)

(define deps
  '("base"
    "rhombus-lib"
    ["rhombus-ffi-lib" #:version "1.1"]))

(define pkg-desc "essential Rhombus bindings for the Enlightenment Foundation Libraries")
(define license '(Apache-2.0 OR MIT))
(define version "0.1")
(define language-families '("Rhombus"))
