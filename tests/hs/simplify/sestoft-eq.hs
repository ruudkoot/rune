-- Sestoft's trees (D34's B) call a literal's (==) where the Report's order
-- does (3.17.2) and nowhere else: N's (==) is an error at 13, and equal
-- modulo 10 otherwise, so a call the Report does not make diverges, and
-- one it makes gives its own answer, which a structural test would not.
-- g's literal clauses are ones the tree does not take apart, left out
-- where the list is known to be empty (HsMatch's `refuted`).
-- sestoft: as A
module Main where

newtype N = N Int deriving Show

instance Eq N where
  N a == N b | a == 13 || b == 13 = error "(==) at 13"
             | otherwise = a `mod` 10 == b `mod` 10

instance Num N where
  N a + N b = N (a + b)
  N a - N b = N (a - b)
  N a * N b = N (a * b)
  negate (N a) = N (negate a)
  abs (N a) = N (abs a)
  signum (N a) = N (signum a)
  fromInteger n = N (fromInteger n)

-- the first clause matches by its second column: no (==)
f :: N -> Bool -> Int
f _ True = 0
f 3 False = 1
f _ _ = 2

-- a literal under a constructor: (==) only once the list is a cons
g :: [N] -> Int
g [] = 0
g (5 : _) = 1
g (_ : 7 : _) = 2
g _ = 3

-- the literal in a later column than the one the clause before tested
h :: Bool -> N -> Int
h True _ = 0
h False 4 = 1
h _ _ = 2

main :: IO ()
main = do
  print (f (N 13) True)
  print (f (N 23) False)
  print (f (N 4) False)
  print (g [])
  print (g [N 15])
  print (g [N 6, N 17])
  print (g [N 6])
  print (h True (N 13))
  print (h False (N 14))
  print (h False (N 13))
