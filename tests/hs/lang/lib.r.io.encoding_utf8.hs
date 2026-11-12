-- rows: R5
-- Report 21: how a Char above 255 is written to a file is not said. rhc's (R5): a file's characters are UTF-8 on
-- every host, so "\256\8364" is five bytes (C4 80 E2 82 AC) and reads back as two characters; a byte that begins no
-- UTF-8 sequence, written by the system, is read as the character of its own value (255).
module Main (main) where

import IO
import System

main :: IO ()
main = do
  writeFile "u.txt" "\256\8364"
  h <- openFile "u.txt" ReadMode
  n <- hFileSize h
  hClose h
  s <- readFile "u.txt"
  print (n, s, length s)
  _ <- system "printf '\\377ab' > raw.txt"
  r <- readFile "raw.txt"
  print r
