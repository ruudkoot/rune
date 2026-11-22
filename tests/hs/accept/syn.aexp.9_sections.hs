-- rows: syn.aexp.10 syn.aexp.11 syn.aexp.12 syn.r.section.minus R67
-- Report 9.5: aexp -> ( exp(i+1) qop(a,i) ) | ( lexp(i) qop(l,i) ) | ( qop(a,i)<-> exp(i+1) ) | ( qop(r,i)<-> rexp(i) ):
-- sections of each form, the operand of a left-associative operator's left section a left-nested expression of
-- its level, and of a right-associative one's right section a right-nested one; (- 1) is no section.
module Main (main) where

main :: IO ()
main = print ((+ 1) 2, (1 +) 2, (2 - 1 -) 3, (++ [1] ++ [2]) [0], (`div` 2) 7, (7 `div`) 2, (- 1) :: Int)
