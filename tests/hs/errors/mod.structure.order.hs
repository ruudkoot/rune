-- Report 5.1: import declarations come before the top-level declarations: not x = 1 then an import.
module Main (main) where

x :: Int
x = 1
import Char

main :: IO ()
main = return ()
