-- Report 17.9: a bottom probe of zipWith4, the Report's own definition its reference: zipWith4 (\_ _ _ _ -> 0) [u] [u] [u] [u] is not;
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
  mapM_ print (take 5 (zipWith4 (\_ _ _ _ -> 0) [u] [u] [u] [u]))
