-- Report 9.5: fbind -> qvar = exp: a field binding has its = exp: no pun.
module Main (main) where

data R = R { a :: Int }

f :: Int -> R
f a = R {a}

main :: IO ()
main = return ()
