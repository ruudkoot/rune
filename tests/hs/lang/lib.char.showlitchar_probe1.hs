-- Report 19.1: a bottom probe of showLitChar, the Report's own definition its reference: showLitChar '\200' undefined is bottom;
-- a marker, then the term, element by element.
module Main (main) where

import Char

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  mapM_ print (take 5 (showLitChar '\200' undefined))
