-- Report 3: free variables and constructors of the translations always refer to the Prelude's entities, whatever is
-- in scope: a failed match ends the program as the Prelude's error does, not as the module's error.
module Main (main) where

import Prelude hiding (error)

error :: String -> Int
error _ = 0

f :: Int -> Int
f x = case x of
  1 -> 10

main :: IO ()
main = do
  print (error "not mine")
  print (f 2)
