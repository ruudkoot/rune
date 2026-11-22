-- A match that fails is a bottom (3.17.3, rule (b)): the program ends as error does, after what it printed.
module Main (main) where

only :: Maybe Int -> Int
only (Just n) = n

main :: IO ()
main = do
  print (only (Just 1))
  print (only Nothing)
