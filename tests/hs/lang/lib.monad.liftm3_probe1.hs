-- Report 20.4: a bottom probe of liftM3, the Report's own definition its reference: liftM3 (\_ _ c -> c) [u] [u, u] [3] is not;
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
  mapM_ print (take 5 (liftM3 (\_ _ c -> c) [u] [u, u] [3]))
