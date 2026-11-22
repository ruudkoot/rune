-- Report 20.4: a bottom probe of liftM, the Report's own definition its reference: liftM (const 1) (Just u) is not;
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
  print (liftM (const 1) (Just u))
