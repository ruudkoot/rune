-- Report 3.17.1: a field pattern names a field once.
module Main (main) where

data T = C1 {f1, f2 :: Int} | C2 {f1 :: Int, f3, f4 :: Char}

g :: T -> Int
g (C1 {f1 = x, f1 = y}) = x

main :: IO ()
main = return ()
