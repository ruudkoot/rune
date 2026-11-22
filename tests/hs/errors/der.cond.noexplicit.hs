-- Report 10: a derived instance may not also be declared.
module Main (main) where

data T = A deriving Eq

instance Eq T

main :: IO ()
main = return ()
