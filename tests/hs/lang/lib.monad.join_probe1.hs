-- Report 20.4: a bottom probe of join, the Report's own definition its reference: join [[1], undefined] is bottom;
-- a marker, then the term, element by element.
module Main (main) where

import Monad

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  mapM_ print (take 5 (join [[1], undefined]))
