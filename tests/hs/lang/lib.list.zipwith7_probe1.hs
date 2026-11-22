-- Report 17.9: a bottom probe of zipWith7, the Report's own definition its reference: zipWith7 (\_ _ _ _ _ _ g -> g) [u] [u] [u] [u] [u] [u] [7] is not;
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
  mapM_ print (take 5 (zipWith7 (\_ _ _ _ _ _ g -> g) [u] [u] [u] [u] [u] [u] [7]))
