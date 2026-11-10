-- Report 6.3.2: functions are not in Ord.
module Main (main) where

x :: Bool
x = id < (id :: Int -> Int)

main :: IO ()
main = return ()
