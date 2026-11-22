-- Report 20.4: a bottom probe of liftM5, the Report's own definition its reference: liftM5 (\a _ _ _ _ -> a) [5] [u] [u] [u] [u] is not;
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
  mapM_ print (take 5 (liftM5 (\a _ _ _ _ -> a) [5] [u] [u] [u] [u]))
