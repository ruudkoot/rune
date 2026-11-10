-- Report 4.2.1: in data T = C { x :: !Int, y :: Int }, y is lazy and x strict.
module Main (main) where

data T = C { x :: !Int, y :: Int }

main :: IO ()
main = do
  print (x (C {x = 1, y = undefined}))
  print (y (C {x = undefined, y = 2}))
