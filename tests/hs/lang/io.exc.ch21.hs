-- Report 7.3: the I/O functions of the Prelude raise chapter 21's errors, which IO's predicates tell apart:
-- readFile of a file that is not there (isDoesNotExistError), getChar at the end of the input (isEOFError),
-- writeFile into a directory that is not there (isDoesNotExistError), and appendFile to a file open for reading
-- (isAlreadyInUseError, 21.2.3's locks); userError's (isUserError), raised by ioError and caught by catch.
module Main (main) where

import IO

kind :: IOError -> String
kind e
  | isDoesNotExistError e = "isDoesNotExistError"
  | isAlreadyInUseError e = "isAlreadyInUseError"
  | isEOFError e = "isEOFError"
  | isUserError e = "isUserError"
  | otherwise = "another"

caught :: IO a -> IO String
caught act = catch (act >> return "no error") (return . kind)

main :: IO ()
main = do
  a <- caught (readFile "missing.txt" >>= \s -> length s `seq` return ())
  b <- caught getChar
  c <- caught (writeFile "no/such/dir/f.txt" "x")
  writeFile "held.txt" "x"
  h <- openFile "held.txt" ReadMode
  d <- caught (appendFile "held.txt" "y")
  hClose h
  e <- caught (ioError (userError "mine"))
  mapM_ putStrLn [a, b, c, d, e]
