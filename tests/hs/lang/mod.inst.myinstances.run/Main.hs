-- Report 5.4's example: import MyInstances () brings its Show instances of functions and of IO actions.
module Main (main) where

import MyInstances ()

main :: IO ()
main = do
  putStrLn (show (id :: Int -> Int))
  putStrLn (show (return () :: IO ()))
