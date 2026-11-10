-- rows: io.appendfile io.readfile io.writefile.literal io.seq.example
-- Report 7.1: writeFile writes, appendFile appends, readFile reads a file; appendFile of show of a list of pairs, as the
-- Report's example does (at Int here); 7.2: readFile, writeFile and putStr chained by >>= and >>, as its example.
module Main (main) where

import Char

main :: IO ()
main = do
  writeFile "t.txt" "one\n"
  appendFile "t.txt" "two\n"
  s <- readFile "t.txt"
  putStr s
  writeFile "squares" ""
  appendFile "squares" (show [(x, x * x) | x <- [0, 1, 2 :: Int]])
  readFile "squares" >>= putStrLn
  writeFile "input-file" "abc\n"
  readFile "input-file" >>= \ s -> writeFile "output-file" (filter isAscii s) >> putStr "Filtering successful\n"
  readFile "output-file" >>= putStr
