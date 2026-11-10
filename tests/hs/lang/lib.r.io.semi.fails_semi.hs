-- rows: lib.r.io.semi.hclose lib.r.io.semi.close.hclose lib.r.io.semi.close.end lib.r.io.semi.fixed lib.r.io.lock.reader lib.r.io.lock.semi lib.r.io.lock.readfile
-- Report 21.2.2, 21.2.3: after hGetContents a handle is semi-closed: hGetChar and hGetContents fail on it, hClose does not
-- and closes it, what was read before stays and the rest may be cut; read to the end, it is closed; a file has
-- any number of readers but no writer while one is open or semi-closed; readFile holds the file until its
-- contents are read, so writeFile fails before and succeeds after. The expected output is written from the text
-- (GHC makes a read after hClose an error).
module Main (main) where

import IO

failed :: IO a -> IO Bool
failed act = try act >>= return . either (const True) (const False)

main :: IO ()
main = do
  writeFile "semi.txt" "abcdef"
  h <- openFile "semi.txt" ReadMode
  s <- hGetContents h
  f1 <- failed (hGetChar h)
  f2 <- failed (hGetContents h)
  lk <- failed (openFile "semi.txt" WriteMode)
  r2 <- openFile "semi.txt" ReadMode
  print (f1, f2, lk)
  print (take 2 s)
  hClose h
  c <- hIsClosed h
  print (take 2 s, length s >= 2, c)
  s2 <- hGetContents r2
  print (s2, length s2)
  c2 <- hIsClosed r2
  print c2
  hClose r2
  h3 <- openFile "semi.txt" ReadMode
  h4 <- openFile "semi.txt" ReadMode
  lk2 <- failed (openFile "semi.txt" AppendMode)
  mapM_ hClose [h3, h4]
  t <- readFile "semi.txt"
  lk3 <- failed (writeFile "semi.txt" "new")
  print (lk2, lk3, length t)
  writeFile "semi.txt" "new"
  readFile "semi.txt" >>= putStrLn
