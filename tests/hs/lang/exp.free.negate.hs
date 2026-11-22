-- Report 3: free variables and constructors of the translations always refer to the Prelude's entities, whatever is
-- in scope: -x uses the Prelude's negate, not the module's, which aborts.
module Main (main) where

import Prelude hiding (negate)

negate :: Int -> Int
negate _ = error "own negate"

main :: IO ()
main = do
  let x = 3 :: Int
  print (-x)
