-- Report 2.6: string -> " ... ": a string needs its closing quote on its line.
module Main (main) where

s :: String
s = "never closed

main :: IO ()
main = return ()
