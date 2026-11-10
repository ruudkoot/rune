-- rows: R84
-- Report 7.1, readings.md R84: readFile is lazy; this runs now, and waits for a --count budget that bounds what reading the
-- head of a large file costs (tests/hs/perf, rhc's policy).
module Main (main) where

main :: IO ()
main = do
  writeFile "big.txt" (concat (replicate 20000 "0123456789\n"))
  s <- readFile "big.txt"
  putStrLn (take 10 s)
