-- Report 7.2: the Report's example with do, its prompts by putStrLn (erratum of February 2008), the input file made
-- first and the output read back.
module Main (main) where

import Char

main :: IO ()
main = do
  writeFile "in.txt" "abc\n"
  putStrLn "Input file:"
  ifile <- getLine
  putStrLn "Output file:"
  ofile <- getLine
  s <- readFile ifile
  writeFile ofile (filter isAscii s)
  putStr "Filtering successful\n"
  readFile ofile >>= putStr
