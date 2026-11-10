-- Report 18.1: fromJust Nothing is an error.
module Main (main) where

import Maybe

main :: IO ()
main = do
  putStrLn "before"
  print (fromJust (Nothing :: Maybe Int))
