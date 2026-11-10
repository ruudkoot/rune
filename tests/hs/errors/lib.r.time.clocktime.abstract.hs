-- Report 24: ClockTime is abstract: import Time (ClockTime(..)) brings no constructor.
module Main (main) where

import Time (ClockTime(..))

x :: ClockTime
x = TOD 0 0

main :: IO ()
main = return ()
