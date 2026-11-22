-- Report 4.3.3: not Functor.
module Main (main) where

data T a = A a deriving Functor

main :: IO ()
main = return ()
