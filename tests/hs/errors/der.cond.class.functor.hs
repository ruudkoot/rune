-- Report 10: Functor is not derivable in Haskell 98.
module Main (main) where

data T a = A a deriving Functor

main :: IO ()
main = return ()
