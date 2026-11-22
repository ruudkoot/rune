-- Report 17.7: genericIndex, as (!!), is an error at an index past the end.
module Main (main) where

import List

main :: IO ()
main = do
  putStrLn "before"
  print (genericIndex "ab" (2 :: Integer))
