-- Report 17.9: a bottom probe of group, the Report's own definition its reference: head (group (1 : 2 : ul)) is not;
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
  mapM_ print (take 5 (head (group (1 : 2 : ul))))
