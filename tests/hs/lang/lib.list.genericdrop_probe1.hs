-- Report 17.9: a bottom probe of genericDrop, the Report's own definition its reference: genericDrop (1 :: Integer) [u, 2] is not;
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
  mapM_ print (take 5 (genericDrop (1 :: Integer) [u, 2]))
