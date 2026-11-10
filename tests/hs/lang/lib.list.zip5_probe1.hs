-- Report 17.9: a bottom probe of zip5, the Report's own definition its reference: length (zip5 [1] ul [] [] []) is bottom;
-- a marker, then the term.
module Main (main) where

import List

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (length (zip5 [1] ul [] [] []))
