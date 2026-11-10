-- Report 4.3.3: not Monad.
module Main (main) where

data T a = A a deriving Monad

main :: IO ()
main = return ()
