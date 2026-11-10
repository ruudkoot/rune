-- Report 3.6: an if has its branches' type.
module Main (main) where

f :: Bool -> Int
f c = (if c then 1 else 2 :: Int)

main :: IO ()
main = return ()
