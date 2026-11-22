-- Report 4.2.3: a newtype has exactly one constructor: not A Int | B Int.
module Main (main) where

newtype T = A Int | B Int

main :: IO ()
main = return ()
