-- Report 20.4: a bottom probe of filterM, the Report's own definition its reference: length (head (filterM (const [True]) [u, u])) is not;
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
  print (length (head (filterM (const [True]) [u, u])))
