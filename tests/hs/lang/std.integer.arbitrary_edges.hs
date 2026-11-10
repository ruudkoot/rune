-- rows: std.integer.arbitrary
-- Report 6.4: Integer is arbitrary precision, here across the edges of the small values that rhc's Integer, as
-- Rune's IntInf, holds immediately (63 bits, -2^62 to 2^62-1; D20, M31), each operation on both sides of them.
module Main (main) where

big, small :: [Integer]
big = [2^62 - 1, 2^62, -(2^62), -(2^62) - 1, 2^63, -(2^63), 2^64 + 7, -(3^41)]
small = [1, -1, 2, -3, 7, 1000000007]

main :: IO ()
main = do
  print big
  print [a + b | a <- big, b <- big]
  print [a - b | a <- big, b <- small]
  print [a * b | a <- big, b <- small]
  print [(a `quot` b, a `rem` b, a `div` b, a `mod` b) | a <- big, b <- small]
  print [(a `quot` b, a `rem` b, a `div` b, a `mod` b) | a <- big, b <- big]
  print [compare a b | a <- big, b <- big]
  print (map negate big, map abs big, map signum big)
  print (map (\a -> gcd a 1000000007) big, product big)
  print (fromInteger (2^62 - 1) :: Int, fromInteger (-(2^62)) :: Int)
  print (read "-36893488147419103232" :: Integer, show (2^100 :: Integer))
  print ((2^62 :: Integer) == 2^61 * 2, (2^62 - 1 :: Integer) < 2^62, [2^62 - 2 .. 2^62 + 1 :: Integer])
