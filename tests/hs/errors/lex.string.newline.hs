-- Report 2.6: a string holds no raw newline outside a gap.
module Main (main) where

s :: String
s = "a
b"

main :: IO ()
main = return ()
