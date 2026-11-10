-- Report 17.9: a bottom probe of zip4, the Report's own definition its reference: length (zip4 [] ul ul ul) is not;
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
  print (length (zip4 [] ul ul ul))
