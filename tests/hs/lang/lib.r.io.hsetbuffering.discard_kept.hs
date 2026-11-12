-- rows: R158
-- Report 21.6: changing a handle that is not writable to NoBuffering "discards" its buffer. rhc keeps the input it
-- has read ahead and not given (R158): the characters after the first are the file's next, as before the change.
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
