-- Report 2.6: charesc -> a | b | f | n | r | t | v | \ | " | ' | &, and no other: `\Q` is none.
module Main (main) where

s :: String
s = "\Q"

main :: IO ()
main = return ()
