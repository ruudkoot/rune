-- D30's tie-break case: f in A and g in B, unsigned and mutually recursive,
-- one declaration group with one context (R21): v, g's parameter, is not
-- in f's type, so it is ambiguous, and defaulting decides it. Num v arose in
-- A, whose default is (Integer, Double), and RealFrac v in B, whose default
-- is (Int, Float): the two modules would give Double and Float, so rhc
-- refuses, under either setting of --cycle-default (D30).
module A (f) where

import B

default (Integer, Double)

f b = g b 2.5
