-- Report 3: a case is an exp10, so no unparenthesised argument: f case x of {y -> y}.
module Main (main) where

x :: Int
x = negate case 1 of { y -> y }

main :: IO ()
main = return ()
