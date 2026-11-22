-- Report 10: Monad is not derivable.
module Main (main) where

data T a = A a deriving Monad

main :: IO ()
main = return ()
