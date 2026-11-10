-- rows: R91
-- Report 10, readings.md R91: a derived Eq T in one module and an explicit Eq T in another are refused, at link.
module Main (main) where

import M

instance Eq T where
  _ == _ = False

main :: IO ()
main = print (A == A)
