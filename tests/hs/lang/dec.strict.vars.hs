-- Report 4.2.1: in data T = C { x, y :: !Int } both are strict.
module Main (main) where

data T = C { x, y :: !Int }

main :: IO ()
main = do
  print (x (C {x = 1, y = 2}))
  print (x (C {x = 1, y = undefined}))
