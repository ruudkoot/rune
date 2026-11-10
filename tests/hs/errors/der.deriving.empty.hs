-- Report 10: deriving () derives nothing: show A is refused.
module Main (main) where

data T = A deriving ()

x :: String
x = show A

main :: IO ()
main = return ()
