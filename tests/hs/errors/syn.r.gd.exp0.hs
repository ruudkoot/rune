-- Report 9.5: gd -> | exp0: a guard holds no expression signature (in parentheses it would).
module Main (main) where

f :: Bool -> Int
f x | x :: Bool = 1

main :: IO ()
main = return ()
