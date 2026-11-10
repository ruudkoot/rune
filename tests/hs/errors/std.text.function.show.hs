-- Report 6.3.3: functions are not in Show.
module Main (main) where

x :: String
x = show (id :: Int -> Int)

main :: IO ()
main = return ()
