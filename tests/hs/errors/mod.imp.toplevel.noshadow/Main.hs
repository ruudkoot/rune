-- Report 5.3: a top-level definition does not shadow an import: both are in scope, and x is ambiguous.
module Main (main) where

import A (x)

main :: IO ()
main = print y

x :: Int
x = 1

y :: Int
y = x
