-- Report 5.5.1: M.x names the top-level x of M though a local x shadows it.
module Main (main) where

x :: Int
x = 1

f :: Int
f = let x = 2 in Main.x

main :: IO ()
main = print f
