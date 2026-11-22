-- Report 4.3.4: so is such an inferred type.
module Main (main) where

f :: Int
f = length (show (read "x"))

main :: IO ()
main = return ()
