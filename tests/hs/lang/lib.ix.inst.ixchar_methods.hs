-- rows: lib.ix.inst.ixint lib.ix.inst.ixinteger lib.ix.inst.ixacb lib.ix.inst.ixbool lib.ix.inst.ixordering lib.ix.inst.ix lib.r.ix.index lib.r.ix.range lib.r.ix.inrange lib.r.ix.instances lib.r.ix.tuple.scheme lib.r.ix.law.index lib.r.ix.law.inrange lib.r.ix.law.map
-- Report 15.1, 15.2: Ix at Char, Int and Integer against the Report's code copied under new names; pairs and triples
-- against Figure 15.1's scheme, the rightmost index varying fastest; Bool, Ordering and () as derived; and the
-- three laws (the map law as the erratum of March 2003 writes it) on each.
module Main (main) where

import Ix

rangeC :: (Char, Char) -> [Char]
rangeC (m, n) = [m .. n]
indexC :: (Char, Char) -> Char -> Int
indexC b@(c, c') ci | inRangeC b ci = fromEnum ci - fromEnum c
                     | otherwise = error "Ix.index: Index out of range."
inRangeC :: (Char, Char) -> Char -> Bool
inRangeC (c, c') i = c <= i && i <= c'

rangeI :: (Int, Int) -> [Int]
rangeI (m, n) = [m .. n]
indexI :: (Int, Int) -> Int -> Int
indexI b@(m, n) i | inRangeI b i = i - m
                  | otherwise = error "Ix.index: Index out of range."
inRangeI :: (Int, Int) -> Int -> Bool
inRangeI (m, n) i = m <= i && i <= n

rangeZ :: (Integer, Integer) -> [Integer]
rangeZ (m, n) = [m .. n]
indexZ :: (Integer, Integer) -> Integer -> Int
indexZ b@(m, n) i | inRangeZ b i = fromInteger (i - m)
                  | otherwise = error "Ix.index: Index out of range."
inRangeZ :: (Integer, Integer) -> Integer -> Bool
inRangeZ (m, n) i = m <= i && i <= n

rangeP :: (Ix a, Ix b) => ((a, b), (a, b)) -> [(a, b)]
rangeP ((l, l'), (u, u')) = [(i, i') | i <- range (l, u), i' <- range (l', u')]
indexP :: (Ix a, Ix b) => ((a, b), (a, b)) -> (a, b) -> Int
indexP ((l, l'), (u, u')) (i, i') = index (l, u) i * rangeSize (l', u') + index (l', u') i'
inRangeP :: (Ix a, Ix b) => ((a, b), (a, b)) -> (a, b) -> Bool
inRangeP ((l, l'), (u, u')) (i, i') = inRange (l, u) i && inRange (l', u') i'

rangeT :: (Ix a, Ix b, Ix c) => ((a, b, c), (a, b, c)) -> [(a, b, c)]
rangeT ((l1, l2, l3), (u1, u2, u3)) = [(i1, i2, i3) | i1 <- range (l1, u1), i2 <- range (l2, u2), i3 <- range (l3, u3)]
indexT :: (Ix a, Ix b, Ix c) => ((a, b, c), (a, b, c)) -> (a, b, c) -> Int
indexT ((l1, l2, l3), (u1, u2, u3)) (i1, i2, i3) = index (l3, u3) i3 + rangeSize (l3, u3) * (index (l2, u2) i2 + rangeSize (l2, u2) * index (l1, u1) i1)
inRangeT :: (Ix a, Ix b, Ix c) => ((a, b, c), (a, b, c)) -> (a, b, c) -> Bool
inRangeT ((l1, l2, l3), (u1, u2, u3)) (i1, i2, i3) = inRange (l1, u1) i1 && inRange (l2, u2) i2 && inRange (l3, u3) i3

laws :: (Ix a) => (a, a) -> [a] -> Bool
laws b xs = and [range b !! index b i == i | i <- range b] && and [inRange b i == (i `elem` range b) | i <- xs]
            && map (index b) (range b) == [0 .. rangeSize b - 1]

main :: IO ()
main = do
  print (and [(range b, map (index b) (range b), map (inRange b) xs) == (rangeC b, map (indexC b) (rangeC b), map (inRangeC b) xs) | b <- [('a', 'e'), ('x', 'x'), ('e', 'a')], let xs = "a e!z"])
  print (and [(range b, map (index b) (range b), map (inRange b) xs) == (rangeI b, map (indexI b) (rangeI b), map (inRangeI b) xs) | b <- [(-2, 3), (5, 5), (3, -2)], let xs = [-3, -2, 0, 3, 4]])
  print (and [(range b, map (index b) (range b), map (inRange b) xs) == (rangeZ b, map (indexZ b) (rangeZ b), map (inRangeZ b) xs) | b <- [(10 ^ 20, 10 ^ 20 + 3), (0, -1)], let xs = [0, 10 ^ 20 + 1]])
  print (and [(range b, map (index b) (range b), map (inRange b) xs) == (rangeP b, map (indexP b) (rangeP b), map (inRangeP b) xs) | b <- [((1, 'a'), (2, 'c')), ((0, 'b'), (0, 'b')), ((2, 'a'), (1, 'c')) :: ((Int, Char), (Int, Char))], let xs = [(1, 'a'), (2, 'd'), (0, 'b')]])
  print (and [(range b, map (index b) (range b), map (inRange b) xs) == (rangeT b, map (indexT b) (rangeT b), map (inRangeT b) xs) | b <- [((0, False, LT), (1, True, GT)), ((1, True, EQ), (1, True, EQ)) :: ((Int, Bool, Ordering), (Int, Bool, Ordering))], let xs = [(0, True, GT), (2, False, LT)]])
  print (range (False, True), index (False, True) True, inRange (True, True) False)
  print (range (LT, GT), index (LT, GT) GT, range ((), ()), index ((), ()) (), inRange ((), ()) ())
  print (range ((1, 1), (2, 2)) :: [(Int, Int)], index ((1, 1), (2, 2)) (2, 1 :: Int), index ((0, 0, 0), (1, 1, 1)) (1, 0, 1 :: Int))
  print [laws ('a', 'd') "a d!", laws (2, 6 :: Int) [1, 2, 6, 7], laws (3, 5 :: Integer) [2, 4], laws (False, True) [True], laws (LT, GT) [EQ], laws ((), ()) [()]]
  print [laws ((1, 'a'), (2, 'c') :: (Int, Char)) [(1, 'b'), (3, 'a')], laws ((0, 0, 0), (1, 2, 1) :: (Int, Int, Int)) [(1, 2, 1), (1, 3, 0)], laws ((2, 1), (1, 2) :: (Int, Int)) [(1, 1)]]
