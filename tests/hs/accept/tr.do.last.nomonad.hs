-- Report 3.14: do {e} = e: do {3} :: Int (readings.md R56).
module Main (main) where

x :: Int
x = do { 3 }

main :: IO ()
main = return ()
