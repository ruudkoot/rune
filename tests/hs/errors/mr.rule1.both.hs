-- Report 4.5.5: Rule 1 applies at the top and nested alike: a nested unsigned binding at two types.
module Main (main) where

main :: IO ()
main = print (h ())
  where
    h _ = (f (1 :: Int), f (1.5 :: Double))
    f = \x -> x + 1
