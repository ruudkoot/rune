-- rows: R11
-- Report 3.5 (readings.md R11): a section's e may be shared; rhc's policy is that it is, which the --count budget
-- tests/hs/perf/tr.sec.sharing holds (hs/perf/tr.sec.sharing); the value is the Report's either way.
module Main (main) where

expensive :: Int
expensive = sum [1 .. 2000]

main :: IO ()
main = print (sum (map (expensive +) [1 .. 100]))
