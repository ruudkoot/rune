-- Report 20.4: a bottom probe of msum, the Report's own definition its reference: msum [Just 1, undefined] is not;
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
  print (msum [Just 1, undefined])
