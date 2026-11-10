-- rows: exp.free.prelude
-- Report 3: free variables and constructors of the translations always refer to the Prelude's entities, whatever is
-- in scope: a comprehension uses the Prelude's concatMap, not the module's, which aborts.
module Main (main) where

import Prelude hiding (concatMap)

concatMap :: (a -> [b]) -> [a] -> [b]
concatMap _ _ = error "own concatMap"

main :: IO ()
main = print [x * 2 | x <- [1, 2 :: Int]]
