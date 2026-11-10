-- Report 3.16: a signature may be more specific than the principal type.
module Main (main) where

i :: Int -> Int
i = id :: Int -> Int

main :: IO ()
main = return ()
