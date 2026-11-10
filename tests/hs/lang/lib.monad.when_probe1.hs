-- Report 20.4: a bottom probe of when, the Report's own definition its reference: when False undefined :: Maybe () is not;
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
  print (when False undefined :: Maybe ())
