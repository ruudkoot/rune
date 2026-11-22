-- Report 17.9: a bottom probe of tails, the Report's own definition its reference: map head (take 1 (tails (1 : ul))) is not;
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
  mapM_ print (take 5 (map head (take 1 (tails (1 : ul)))))
