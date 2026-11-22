-- Report 20.4: a bottom probe of zipWithM, the Report's own definition its reference: head (zipWithM (\a _ -> [a]) [1, 2] [u, u]) is not;
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
  mapM_ print (take 5 (head (zipWithM (\a _ -> [a]) [1, 2] [u, u])))
