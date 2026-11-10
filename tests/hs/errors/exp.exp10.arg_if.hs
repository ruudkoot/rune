-- Report 3: an if is an exp10, so no unparenthesised argument: f if a then b else c.
module Main (main) where

x :: Int
x = negate if True then 1 else 2

main :: IO ()
main = return ()
