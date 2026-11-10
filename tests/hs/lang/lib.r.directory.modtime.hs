-- Report 22: a file's modification time does not go back when the file is written again. It waits for B's primitives for the file system.
module Main (main) where

import Directory

main :: IO ()
main = do
  writeFile "m" "1"
  t1 <- getModificationTime "m"
  writeFile "m" "2"
  t2 <- getModificationTime "m"
  print (t2 >= t1)
