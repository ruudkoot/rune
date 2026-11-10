-- Clauses in order, each one's patterns left to right (4.4.3.1, 3.17.2): the first clause that matches is taken, and
-- a pattern is tried only once those left of it have matched.
module Main (main) where

f :: Int -> Int -> Int
f 0 _ = 1
f _ 0 = 2
f _ _ = 3

-- the first argument is not forced where the first clause matches on the second
g :: Int -> Int -> Int
g _ 0 = 2
g 0 _ = 1
g _ _ = 3

h :: Maybe Int -> Int
h (Just 1) = 10
h (Just n) = n
h Nothing = 0

firstOf :: [Int] -> Int
firstOf (x : _) = x
firstOf [] = 0

pairs :: (Bool, Bool) -> Int
pairs (True, True) = 1
pairs (True, _) = 2
pairs (_, True) = 3
pairs _ = 4

main :: IO ()
main = do
  print (f 0 5)
  print (f 5 0)
  print (f 0 0)
  print (f 5 5)
  print (g undefined 0)
  print (h (Just 1))
  print (h (Just 4))
  print (h Nothing)
  print (firstOf [7, 8])
  print (firstOf [])
  print (map pairs [(True, True), (True, False), (False, True), (False, False)])
