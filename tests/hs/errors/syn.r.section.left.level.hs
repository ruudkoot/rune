-- Report 9.5: aexp -> ( exp(i+1) qop(a,i) ) | ( lexp(i) qop(l,i) ): the operand of a left section binds
-- tighter than its operator, so not (a + b *).
module Main (main) where

main :: IO ()
main = print ((1 + 2 *) 3)
