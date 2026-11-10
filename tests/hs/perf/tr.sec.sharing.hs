-- Report 3.5 (readings.md R11): a section's e may be shared, and rhc's policy is that it is: map (expensive n +) over n
-- elements costs about n with e shared and n^2 without. tr.sec.sharing.budget: the count at 2n against n.
module Main (main) where

expensive :: Int -> Int
expensive n = sum [1 .. n]

main :: IO ()
main = do
  n <- readLn
  print (sum (map (expensive n +) [1 .. n]))
