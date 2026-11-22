-- Report 18.1: a bottom probe of fromMaybe, the Report's own definition its reference: fromMaybe 1 (undefined :: Maybe Int) is bottom;
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
  print (fromMaybe 1 (undefined :: Maybe Int))
