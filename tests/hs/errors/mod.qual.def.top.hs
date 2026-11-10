-- Report 5.5.1: a defining occurrence uses the unqualified name: not M.f x = 1 at the top level.
module Main (main) where

Main.f :: Int -> Int
Main.f x = 1

main :: IO ()
main = return ()
