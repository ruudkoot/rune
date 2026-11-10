-- Report 19.1: a bottom probe of readEsc, the Report's own definition its reference: length (readLitChar ('\\' : 'n' : undefined)) is not;
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
  print (length (readLitChar ('\\' : 'n' : undefined)))
