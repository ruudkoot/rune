-- Report 4.4.1: so in a local signature too.
module Main (main) where

f :: a -> [a]
f x = g
  where
    g :: [a]
    g = [x]

main :: IO ()
main = return ()
