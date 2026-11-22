-- Report 4: a data declaration stands only at the top level: not in a where.
module Main (main) where

x :: Int
x = 1 where data T = A

main :: IO ()
main = return ()
