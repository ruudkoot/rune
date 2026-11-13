-- Report 21.7.2: hSeek's offset counts 8-bit bytes. The file holds "\233bc" in UTF-8 (R38: C3 A9 62 63), so byte 2
-- is 'b', and hFileSize is 4: the offset is the file's bytes, not its characters.
module Main (main) where

import IO

main :: IO ()
main = do
  writeFile "s.txt" "\233bc"
  h <- openFile "s.txt" ReadMode
  n <- hFileSize h
  hSeek h AbsoluteSeek 2
  b <- hGetChar h
  hSeek h AbsoluteSeek 0
  e <- hGetChar h
  print (n, b, e)
  hClose h
