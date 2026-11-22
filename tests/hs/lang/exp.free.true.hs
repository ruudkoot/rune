-- rows: exp.free.false
-- Report 3: free variables and constructors of the translations always refer to the Prelude's entities, whatever is
-- in scope: if, guards and [e | True] use the Prelude's True and False, whatever True and False are bound to.
module Main (main) where

import Prelude hiding (Bool (..))

data B = True | False deriving Show

h :: Int -> String
h x | x > 0 = "pos"
    | otherwise = "nonpos"

main :: IO ()
main = do
  print (if (1 :: Int) > 0 then "yes" else "no", h 1, h 0)
  print ([1 | (2 :: Int) > 1] :: [Int], True, False)
