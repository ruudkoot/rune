-- Report 20.4: a bottom probe of ap, the Report's own definition its reference: ap [const 1] [u, u] is not;
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
  mapM_ print (take 5 (ap [const 1] [u, u]))
