-- Report 21.6: with no buffering, an input handle gives the next item when it is asked for: a file's characters
-- one by one under NoBuffering, hLookAhead's character the next hGetChar's, and the standard input's too.
module Main (main) where

import IO

main :: IO ()
main = do
  writeFile "n.txt" "abc"
  h <- openFile "n.txt" ReadMode
  hSetBuffering h NoBuffering
  a <- hGetChar h
  b <- hLookAhead h
  c <- hGetChar h
  d <- hGetChar h
  e <- hIsEOF h
  print (a, b, c, d, e)
  hClose h
  hSetBuffering stdin NoBuffering
  x <- getChar
  y <- getChar
  print (x, y)
