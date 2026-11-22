-- rows: R154
-- Report 19.1: a bottom probe of lexLitChar, the Report's own definition its reference: length (lexLitChar ('a' : undefined)) is not;
-- a marker, then the term.
module Main (main) where

import Char

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (length (lexLitChar ('a' : undefined)))
