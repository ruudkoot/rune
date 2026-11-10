-- Report 17.9: a bottom probe of \\, the Report's own definition its reference: (1 : 2 : ul) \\ [1] is bottom;
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
  mapM_ print (take 5 ((1 : 2 : ul) \\ [1]))
