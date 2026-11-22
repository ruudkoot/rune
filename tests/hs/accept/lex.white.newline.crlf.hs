-- Report 2.2: newline -> return linefeed | return | linefeed | formfeed. Every line of this file ends
-- in return linefeed, one newline each: layout sees the lines as in a file of linefeeds.
module Main (main) where

main :: IO ()
main = do
  print x
  print y
  where
    x = 1 :: Int
    y = 2 :: Int
