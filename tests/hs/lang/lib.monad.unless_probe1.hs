-- Report 20.4: a bottom probe of unless, the Report's own definition its reference: unless True undefined :: Maybe () is not;
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
  print (unless True undefined :: Maybe ())
