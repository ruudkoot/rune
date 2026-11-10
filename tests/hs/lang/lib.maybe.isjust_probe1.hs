-- Report 18.1: a bottom probe of isJust, the Report's own definition its reference: isJust (Just u) is not;
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
  print (isJust (Just u))
