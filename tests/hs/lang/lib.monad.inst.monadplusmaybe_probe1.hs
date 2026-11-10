-- Report 20.4: a bottom probe of mplus, the Report's own definition its reference: Just 1 `mplus` undefined is not;
-- a marker, then the term.
module Main (main) where

import Monad

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (Just 1 `mplus` undefined)
