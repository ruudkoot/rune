-- Report 3.13: a guard is an exp0, with no signature at its top: not case x of { y | y :: Bool -> 1 }.
module Main (main) where

main :: IO ()
main = print (case True of { y | y :: Bool -> 1 })
