-- Report 20.4: a bottom probe of zipWithM_, the Report's own definition its reference: zipWithM_ (\_ _ -> Just ()) [u] [u] is not;
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
  print (zipWithM_ (\_ _ -> Just ()) [u] [u])
