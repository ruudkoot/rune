-- Report 3.13: the alternatives' bodies have one type.
module Main (main) where

f :: Int -> Char
f x = case x of { 1 -> 'a'; _ -> True }

main :: IO ()
main = return ()
