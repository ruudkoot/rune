-- rows: pre.io.readfile pre.io.writefile pre.io.appendfile
-- Report 8.3: writeFile, appendFile and readFile, and interact f = do s <- getContents; putStr (f s).
module Main (main) where

import Char

main :: IO ()
main = do
  writeFile "f.txt" "ab\n"
  appendFile "f.txt" "cd\n"
  readFile "f.txt" >>= putStr
  interact (map toUpper)
