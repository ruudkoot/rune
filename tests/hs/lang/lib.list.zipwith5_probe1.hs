-- Report 17.9: a bottom probe of zipWith5, the Report's own definition its reference: zipWith5 (\a _ _ _ _ -> a) (1 : ul) [u, u] [u, u] [u, u] [u] is bottom;
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
  mapM_ print (take 5 (zipWith5 (\a _ _ _ _ -> a) (1 : ul) [u, u] [u, u] [u, u] [u]))
