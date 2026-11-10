-- Report 17.9: a bottom probe of partition, the Report's own definition its reference: fst (partition even (2 : 1 : 4 : ul)) is bottom;
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
  mapM_ print (take 5 (fst (partition even (2 : 1 : 4 : ul))))
