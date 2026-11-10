-- rows: lib.cputime.cputimeprecision
-- Report 26: each function of CPUTime at its Report type, by a signature; running it does nothing.
module Main (main) where

import CPUTime

getCPUTime' :: IO Integer
getCPUTime' = getCPUTime

cpuTimePrecision' :: Integer
cpuTimePrecision' = cpuTimePrecision

main :: IO ()
main = putStrLn "typed"
