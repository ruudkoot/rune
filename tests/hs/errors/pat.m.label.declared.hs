-- Report 3.17.1: a field pattern names a field of its constructor.
module Main (main) where

data T = C1 {f1, f2 :: Int} | C2 {f1 :: Int, f3, f4 :: Char}

g :: T -> Char
g (C1 {f3 = x}) = x

main :: IO ()
main = return ()
