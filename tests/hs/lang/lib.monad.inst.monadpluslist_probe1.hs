-- Report 20.4: a bottom probe of mplus, the Report's own definition its reference: take 1 ([1] `mplus` ul) is not;
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
  mapM_ print (take 5 (take 1 ([1] `mplus` ul)))
