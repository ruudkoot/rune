-- rows: lib.r.cputime.precision
-- Report 26: getCPUTime is not negative and grows across work; cpuTimePrecision is positive. The work is a sum of
-- 20,000 Integers: the Report's sum is a lazy foldl, a suspension for each term, and 2,000,000 of them exhausted Core's
-- interpreter; the row is about the clock, which this much work still moves (by 0.08 s on the VM, 1.3 s on the
-- interpreter, at a precision of 1 microsecond).
module Main (main) where

import CPUTime

main :: IO ()
main = do
  t1 <- getCPUTime
  print (sum [1 .. 20000 :: Integer] > 0)
  t2 <- getCPUTime
  print (t1 >= 0, t2 >= t1, cpuTimePrecision > 0)
