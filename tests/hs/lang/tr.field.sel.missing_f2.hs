-- Report 3.15.1: a selector applied to a constructor without its field is an error.
module Main (main) where

data T = C1 {f1, f2 :: Int} | C2 {f1 :: Int, f3, f4 :: Char}

main :: IO ()
main = print (f2 (C2 1 'a' 'b'))
