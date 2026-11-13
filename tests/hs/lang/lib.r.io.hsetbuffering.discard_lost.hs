-- rows: R158
-- Report 21.6: changing a handle that is not writable to NoBuffering discards its buffer. rhc follows the text (R158,
-- the lead's ruling 61): the input read ahead and not given is lost, so that hGetContents after the first character of
-- "abcdef", all of which the file's first read buffered, gives nothing. GHC, Hugs, nhc98 and MicroHs keep it
-- (oracles.txt).
module Main (main) where

import IO

main :: IO ()
main = do
  writeFile "k.txt" "abcdef"
  h <- openFile "k.txt" ReadMode
  a <- hGetChar h
  hSetBuffering h NoBuffering
  rest <- hGetContents h
  print (a, rest)
