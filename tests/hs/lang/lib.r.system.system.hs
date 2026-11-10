-- Report 23: system runs a command and gives its exit: true and false. It waits for B's primitives for the process and its environment.
module Main (main) where

import System

main :: IO ()
main = do
  a <- system "true"
  b <- system "false"
  print (a, b == ExitSuccess)
