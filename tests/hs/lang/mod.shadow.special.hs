-- Report 5.6.2, 3: a module that redefines concatMap, enumFrom, >>=, negate, fromInteger, == and fail changes
-- no comprehension, sequence, do, negation, literal or literal pattern.
module Main (main) where

import Prelude hiding (concatMap, enumFrom, (>>=), negate, fromInteger, (==), fail)

concatMap :: Int
concatMap = 0

enumFrom :: Int
enumFrom = 0

(>>=) :: Int
(>>=) = 0

negate :: Int
negate = 0

fromInteger :: Int
fromInteger = 0

(==) :: Int
(==) = 0

fail :: Int
fail = 0

f :: Int -> String
f 0 = "zero"
f _ = "other"

main :: IO ()
main = do
  print [x * 2 | x <- [1, 2 :: Int]]
  print (take 2 [5 :: Int ..])
  n <- return (3 :: Int)
  print (- n, 4 :: Int, f 0)
