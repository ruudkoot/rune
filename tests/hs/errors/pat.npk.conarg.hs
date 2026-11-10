-- Report 3.17.1: an n+k pattern is a pat, no apat, so no unparenthesised argument of a constructor: not Just n+1.
module Main (main) where

f :: Maybe Int -> Int
f (Just n+1) = n
f _ = 0

main :: IO ()
main = return ()
