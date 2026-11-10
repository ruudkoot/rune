-- rows: io.getline io.readln io.seq.bind io.readio.ok
-- Report 7.1: getChar and getLine read the standard input, readLn reads a line and parses it, readIO "1" parses; >>=
-- passes getLine's result on.
module Main (main) where

main :: IO ()
main = do
  c <- getChar
  print c
  l <- getLine
  print l
  l2 <- getLine
  putStrLn l2
  n <- readLn
  print (n + 1 :: Int)
  m <- readIO "1"
  print (m :: Int)
  getLine >>= putStr
  putStrLn ""
