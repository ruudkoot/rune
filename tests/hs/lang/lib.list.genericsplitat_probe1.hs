-- Report 17.9: a bottom probe of genericSplitAt, the Report's own definition its reference: fst (genericSplitAt (1 :: Integer) (1 : ul)) is not;
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
  mapM_ print (take 5 (fst (genericSplitAt (1 :: Integer) (1 : ul))))
