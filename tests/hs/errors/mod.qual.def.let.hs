-- Report 5.5.1: nor in a local definition: not let M.y = x + 1 in y.
module Main (main) where

x :: Int
x = let Main.y = 1 in y

main :: IO ()
main = return ()
