-- Report 21.9.1: hWaitForInput returns True as soon as input is available: on a file with characters left, at once
-- (a timeout of 0) and with a timeout; after its last character the handle is at its end, which is an error
-- (isEOFError). That it returns False where no input comes within t milliseconds needs a source that stays open
-- and silent, which a file is not.
module Main (main) where

import IO

main :: IO ()
main = do
  writeFile "w.txt" "ab"
  h <- openFile "w.txt" ReadMode
  r0 <- hWaitForInput h 0
  r1 <- hWaitForInput h 100
  _ <- hGetChar h
  r2 <- hWaitForInput h 0
  _ <- hGetChar h
  r3 <- try (hWaitForInput h 0)
  print (r0, r1, r2, either isEOFError (const False) r3)
  hClose h
