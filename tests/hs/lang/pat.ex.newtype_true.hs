-- rows: pat.irref.newtype.ref
-- Report 3.17.2: newtype N = N Bool: (\ (N True) -> True) bottom is bottom: True is refutable.
module Main (main) where

newtype N = N Bool

main :: IO ()
main = print ((\(N True) -> True) undefined)
