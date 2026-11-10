-- rows: R43 R89
-- Report 8.2, 10.4, readings.md R89: read skips spaces, tabs and newlines; lex skips no comment, so a comment
-- in read's input fails it.
module Main (main) where

main :: IO ()
main = do
  print (read " \t\n 1 \n" :: Int)
  print (read "1 {- c -}" :: Int)
