-- Report 20.4: a bottom probe of liftM2, the Report's own definition its reference: liftM2 (\_ b -> b) (Just u) (Just 2) is not;
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
  print (liftM2 (\_ b -> b) (Just u) (Just 2))
