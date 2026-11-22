-- rows: exp.free.enumfromthen exp.free.enumfromto exp.free.enumfromthento
-- Report 3: free variables and constructors of the translations always refer to the Prelude's entities, whatever is
-- in scope: arithmetic sequences use the Prelude's enumFrom and its kin, not the module's, which abort.
module Main (main) where

import Prelude hiding (enumFrom, enumFromThen, enumFromTo, enumFromThenTo)

enumFrom :: Int -> [Int]
enumFrom _ = error "own"

enumFromThen :: Int -> Int -> [Int]
enumFromThen _ _ = error "own"

enumFromTo :: Int -> Int -> [Int]
enumFromTo _ _ = error "own"

enumFromThenTo :: Int -> Int -> Int -> [Int]
enumFromThenTo _ _ _ = error "own"

main :: IO ()
main = do
  print (take 3 [1 :: Int ..], take 3 [1 :: Int, 3 ..])
  print ([1 .. 3 :: Int], [1, 3 .. 7 :: Int])
