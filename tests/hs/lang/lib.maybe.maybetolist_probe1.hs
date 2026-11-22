-- Report 18.1: a bottom probe of maybeToList, the Report's own definition its reference: length (maybeToList (Just u)) is not;
-- a marker, then the term.
module Main (main) where

import Maybe

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (length (maybeToList (Just u)))
