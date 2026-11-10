-- Report 3.13: a case has its alternatives' type.
module Main (main) where

f :: Int -> Char
f x = (case x of { 1 -> 'a'; _ -> 'b' } :: Char)

main :: IO ()
main = return ()
