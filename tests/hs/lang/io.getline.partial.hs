-- rows: R46
-- Report 7.1, 21.9: at end of file within a line, getLine returns the partial line (readings.md R46).
module Main (main) where

main :: IO ()
main = do
  l <- getLine
  print l
