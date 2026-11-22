-- Report 4.1.2: no infix type constructor but (->): not x :: Int :+: Int.
module Main (main) where

x :: Int :+: Int
x = undefined

main :: IO ()
main = return ()
