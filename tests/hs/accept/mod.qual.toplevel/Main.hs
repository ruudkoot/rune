-- Report 5.5.1: a top-level declaration brings both its unqualified and its qualified name into scope.
module Main (main) where

f :: Int -> Int
f x = x

g :: Int -> Int
g x = Main.f x

main :: IO ()
main = print (g 1)
