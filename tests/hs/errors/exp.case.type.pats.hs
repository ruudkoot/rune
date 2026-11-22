-- Report 3.13: the patterns have the scrutinee's type.
module Main (main) where

f :: Int
f = case 'a' of { True -> 1 }

main :: IO ()
main = return ()
