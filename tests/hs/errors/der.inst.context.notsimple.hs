-- Report 10: a derived instance's context must be simple: Show (a b) is not.
module Main (main) where

data Apply a b = App (a b) deriving Show

main :: IO ()
main = return ()
