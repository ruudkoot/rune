-- Report 20.4: a bottom probe of foldM, the Report's own definition its reference: foldM (\_ x -> Just x) u [1, 2] is not;
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
  print (foldM (\_ x -> Just x) u [1, 2])
