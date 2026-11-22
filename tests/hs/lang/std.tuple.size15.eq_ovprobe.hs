-- rows: std.tuple.size15.ord std.tuple.size15.bounded std.tuple.size15.show std.tuple.size15.read lib.r.ix.tuples
-- Report 6.1.4, 15.1 (overlay ov.tuples.fifteen; M17's bottom probes on the literal Prelude): the instances of tuples
-- of 4 to 15 components, which the Report gives for pairs and triples alone; the reference is chapter 10's derived
-- instances on data T4 a b c d = T4 a b c d (Eq, Ord, Bounded, Ix) and the pair's Show code, which "other tuples"
-- follow, at 4 components. A marker, then the terms, the last character by character, which ends in bottom.
module Main (main) where

import Ix

u :: Int
u = undefined

q :: Int -> Int -> Int -> Int -> (Int, Int, Int, Int)
q a b c d = (a, b, c, d)

type I15 = (Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int)

a15, b15 :: I15
a15 = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, u)
b15 = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 0)

main :: IO ()
main = do
  putStrLn "probe"
  print (q 1 2 3 u == q 1 2 4 0, compare (q 1 2 3 u) (q 1 2 4 0), a15 == b15, compare a15 b15)
  print (minBound == (False, False, False, False), maxBound == (True, True, True, True))
  print (range (q 0 0 0 0, q 1 0 0 1) == [q 0 0 0 0, q 0 0 0 1, q 1 0 0 0, q 1 0 0 1])
  print (index (q 0 0 0 0, q 1 1 1 1) (q 1 0 1 0), inRange (q 0 0 0 0, q 1 1 1 1) (q 2 u u u))
  print (take 7 (show (q 1 2 3 u)), fst (head (reads "(1,2,3,4)")) == q 1 2 3 4)
  mapM_ print (show (q 1 2 3 u))
