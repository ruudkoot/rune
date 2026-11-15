-- HsMatch's `refuted` under Sestoft's trees (D34's B) leaves out a clause
-- the tree does not take apart (a literal in it) only where the Report's
-- order would fail it forcing nothing: the columns before the first
-- refutable one lazy, and that one's constructor known not to match. Here
-- u's second clause has its first column unknown and its second known not
-- to match: the Report forces the first, which is bottom, before it fails
-- on the second, so the clause must not be left out.
-- sestoft: as A
module Main where

t :: [Int] -> [Int] -> Int
t _ [] = 0
t ~(1:_) (_:_) = 1
t _ _ = 2

v :: [Int] -> Int
v [] = 0
v (1 : _) = 1
v [2, _] = 2
v _ = 3

u :: [Int] -> [Int] -> Int
u _ [] = 0
u (1:_) [] = 1
u _ _ = 2

main :: IO ()
main = do
  print (t undefined [], t undefined [5], t [7] [5])
  print (v [], v [1, 9], v [2, 8], v [2], v [3, 4, 5])
  print (u undefined [])
  print (u [1] [3])
  print (u undefined [3])
