-- rows: R19
-- Report 4.5.5: a non-simple pattern binding is monomorphic in its constrained variables, whatever its
-- signature (R19: refused, D32).
module Main (main) where

(f, g) = ((+), (-))
f :: Num a => a -> a -> a

main :: IO ()
main = return ()
