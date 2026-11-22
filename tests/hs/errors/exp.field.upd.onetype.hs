-- Report 3.15.3: an update names fields of one type.
module Main (main) where

data A = A {a :: Int}
data B = B {b :: Int}

f r = r {a = 1, b = 2}

main :: IO ()
main = return ()
