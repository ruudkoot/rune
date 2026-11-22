-- rows: R38
-- Report 21.2: a file's name is a String whose meaning is the system's. rhc's (R38): the name's characters are its
-- UTF-8 bytes, so the file "\233.txt" made by writeFile is the one the system lists as the bytes C3 A9 2E 74 78 74
-- (shown by the system's own ls, which writes them as they are), and doesFileExist and readFile find it by the name.
module Main (main) where

import Directory
import IO
import System

main :: IO ()
main = do
  createDirectory "names"
  writeFile "names/\233.txt" "x"
  hFlush stdout
  _ <- system "ls names"
  e <- doesFileExist "names/\233.txt"
  s <- readFile "names/\233.txt"
  print (e, s)
  removeFile "names/\233.txt"
  removeDirectory "names"
