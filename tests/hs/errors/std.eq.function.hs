-- Report 6.3.1: functions are not in Eq.
module Main (main) where

x :: Bool
x = id == (id :: Int -> Int)

main :: IO ()
main = return ()
