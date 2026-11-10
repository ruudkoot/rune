-- rows: der.read.standard R43 R82
-- Report 8.2, readings.md R82: read is lex's: read "0x10" :: Int fails, lex reading 0 and leaving x10.
module Main (main) where

main :: IO ()
main = do
  print (lex "0x10")
  print (read "0x10" :: Int)
