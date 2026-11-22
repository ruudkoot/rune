-- Report 4.3.1: a method's type mentions the class variable: not m :: Int.
module Main (main) where

class C a where
  m :: Int

main :: IO ()
main = return ()
