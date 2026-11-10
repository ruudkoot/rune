-- rows: std.tuple.eq std.tuple.ord std.tuple.read std.tuple.show std.tuple.zip7 std.tuple.con std.tuple.pair.fns
-- Report 6.1.4: tuples are algebraic, lazy in their components, with Eq, Ord, Bounded, Read and Show; zip3 is the
-- Prelude's and zip4 to zip7 the List library's; fst, snd, curry and uncurry.
module Main (main) where

import List

main :: IO ()
main = do
  print (case (undefined :: Int, 1 :: Int) of (_, y) -> y)
  print ((1 :: Int, 'a') == (1, 'a'), (1, 2) < (1, 3 :: Int), (2, 0) > (1, 9 :: Int))
  print (read "(1,True)" :: (Int, Bool), show (1 :: Int, True))
  print (zip3 [1, 2 :: Int] "ab" [True, False], unzip3 [(1 :: Int, 'a', True)])
  print (map (\(a, b, c, d) -> a + b + c + d) (zip4 [1] [2] [3] [4 :: Int]))
  print (map (\(a, b, c, d, e, f, g) -> a + b + c + d + e + f + g) (zip7 [1] [2] [3] [4] [5] [6] [7 :: Int]))
  print ((,) 1 2 == (1, 2 :: Int), (,,) 1 2 3 == (1, 2, 3 :: Int))
  print (fst (1 :: Int, undefined :: Int), snd (undefined :: Int, 2 :: Int), curry fst 1 (2 :: Int) :: Int, uncurry (+) (3, 4 :: Int))
