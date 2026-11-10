-- Report 17.9: a bottom probe of elemIndices, the Report's own definition its reference: elemIndices 1 (1 : 2 : 1 : ul) is bottom;
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
  mapM_ print (take 5 (elemIndices 1 (1 : 2 : 1 : ul)))
