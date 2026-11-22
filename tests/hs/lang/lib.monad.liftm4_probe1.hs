-- Report 20.4: a bottom probe of liftM4, the Report's own definition its reference: liftM4 (\_ _ _ d -> d) (Just u) (Just u) (Just u) (Just 4) is not;
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
  print (liftM4 (\_ _ _ d -> d) (Just u) (Just u) (Just u) (Just 4))
