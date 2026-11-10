-- rows: lib.r.cputime.precision
-- Report 26: getCPUTime is not negative and grows across work; cpuTimePrecision is positive. It waits for B's primitive for the processor time.
module Main (main) where

import CPUTime

main :: IO ()
main = do
  t1 <- getCPUTime
  print (sum [1 .. 2000000 :: Integer] > 0)
  t2 <- getCPUTime
  print (t1 >= 0, t2 >= t1, cpuTimePrecision > 0)
