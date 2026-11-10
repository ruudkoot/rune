-- Report 4.1.3: an assertion's type is no tuple: not Eq (a, b).
module Main (main) where

f :: Eq (a, b) => a -> a
f x = x

main :: IO ()
main = return ()
