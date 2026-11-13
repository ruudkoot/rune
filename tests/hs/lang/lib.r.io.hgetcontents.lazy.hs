-- Report 21.2.2: hGetContents reads its items on demand. Of a file of 100,000 characters, three are read, and the
-- handle then closed: the list holds what had been read by then, at least the three and fewer than the file (an
-- implementation may read a buffer's worth ahead; a strict read would hold all 100,000).
module Main (main) where

import IO

main :: IO ()
main = do
  writeFile "lazy.txt" (replicate 100000 'x')
  h <- openFile "lazy.txt" ReadMode
  cs <- hGetContents h
  putStrLn (take 3 cs)
  hClose h
  print (length cs >= 3, length cs < 100000)
