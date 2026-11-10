-- Report 9.5: cdecl -> gendecl | (funlhs | var) rhs: no pattern binding in a class body.
module Main (main) where

class C a where
  (p, q) = (1, 2)

main :: IO ()
main = return ()
