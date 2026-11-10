-- rows: io.getline.eof io.exc.catch io.exc.type
-- Report 7.1: getChar and getLine raise an exception at end of file, which isEOFError identifies; 7.3: catch's handler
-- receives the IOError and its value is the result.
module Main (main) where

import IO

main :: IO ()
main = do
  r <- catch (getChar >> return "char") (\e -> return (if isEOFError e then "eof" else "other"))
  putStrLn r
  r2 <- catch (getLine >> return "line") (\e -> return (if isEOFError e then "eof" else "other"))
  putStrLn r2
