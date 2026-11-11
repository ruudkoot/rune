-- rows: R84
-- Report 7.1, readings.md R84: readFile is lazy; the --count budget tests/hs/perf/io.readfile.lazy bounds what reading
-- the head of a large file costs (hs/perf/io.readfile.lazy, rhc's policy).
module Main (main) where

main :: IO ()
main = do
  writeFile "big.txt" (concat (replicate 20000 "0123456789\n"))
  s <- readFile "big.txt"
  putStrLn (take 10 s)
