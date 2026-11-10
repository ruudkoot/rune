-- Report 4.1.3: class -> qtycls tyvar | qtycls ( tyvar atype1 ... atypen ): an assertion is on a type variable.
module Main (main) where

f :: Eq Int => Int
f = 1

main :: IO ()
main = return ()
