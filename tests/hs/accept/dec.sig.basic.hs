-- rows: dec.sig.shares.nothing dec.sig.patternbound dec.sig.nosig.principal dec.sig.specific
-- Report 4.4.1: a signature of several names gives each the type, each quantified apart; a pattern binding may be signed;
-- unsigned, uses outside the group are at the principal type; a signature may be more specific.
module Main (main) where

f, g :: a -> a
f x = x
g y = y

x, y :: Int
(x, y) = (1, 2)

sqr x = x * x

sqrI :: Int -> Int
sqrI x = x * x

main :: IO ()
main = print (f 'c', g True, x + y, sqr 5, sqr 0.1)
