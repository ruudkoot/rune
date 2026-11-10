-- Report 3.17.1: non-associative constructor operators follow the mixing rule: not a `C` b `C` c.
module Main (main) where

infix 4 `C`
data T = Int `C` Int | E

f :: T -> Int
f (a `C` b `C` c) = a
f _ = 0

main :: IO ()
main = return ()
