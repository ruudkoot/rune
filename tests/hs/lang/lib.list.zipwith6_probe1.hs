-- Report 17.9: a bottom probe of zipWith6, the Report's own definition its reference: zipWith6 (\_ _ _ _ _ f -> f) [u] [u] [u] [u] [u] [6] is not;
-- a marker, then the term, element by element.
module Main (main) where

import List

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  mapM_ print (take 5 (zipWith6 (\_ _ _ _ _ f -> f) [u] [u] [u] [u] [u] [6]))
