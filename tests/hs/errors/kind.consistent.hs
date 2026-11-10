-- Report 4.6: each type is used at one kind in a signature: not m -> m Int.
module Main (main) where

f :: m -> m Int
f = undefined

main :: IO ()
main = return ()
