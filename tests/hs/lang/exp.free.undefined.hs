-- Report 3: free variables and constructors of the translations always refer to the Prelude's entities, whatever is
-- in scope: a field left out of a construction is the Prelude's bottom, not the module's undefined.
module Main (main) where

import Prelude hiding (undefined)

undefined :: Int
undefined = 0

data T = T {a, b :: Int}

main :: IO ()
main = do
  print undefined
  print (b (T {a = 1}))
