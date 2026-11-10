-- Report 3.6: if e1 then e2 else e3 is bottom when e1 is.
module Main (main) where

main :: IO ()
main = print (if undefined then 1 else 2 :: Int)
