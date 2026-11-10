-- rows: lib.cputime.export.cputimeprecision
-- Report 26: module CPUTime exports each of these: an explicit import of every one compiles, and each name is used.
module Main (main) where

import CPUTime (getCPUTime, cpuTimePrecision)

v0 _ = getCPUTime

v1 _ = cpuTimePrecision

main :: IO ()
main = return ()
