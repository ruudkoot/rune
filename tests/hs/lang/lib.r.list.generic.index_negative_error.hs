-- Report 17.7: genericIndex, as (!!), is an error at a negative index.
module Main (main) where

import List

main :: IO ()
main = do
  putStrLn "before"
  print (genericIndex "ab" (-1 :: Integer))
