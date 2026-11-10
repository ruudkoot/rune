-- rows: std.arith.quotrem.law std.arith.divmod.law std.arith.quot std.arith.div std.arith.quotrem std.arith.divmod std.arith.even std.arith.odd std.gcd.def std.gcd.ex1 std.gcd.ex2 std.gcd.ex3 std.lcm.def R45
-- Report 6.4.2: quot truncates toward zero and div toward negative infinity, rem and mod with them, by the laws
-- (x `quot` y)*y + (x `rem` y) == x and (x `div` y)*y + (x `mod` y) == x; even and odd; gcd and lcm.
module Main (main) where

qs :: (Integral a) => [a] -> [(a, a, a, a)]
qs ps = [(x `quot` y, x `rem` y, x `div` y, x `mod` y) | x <- ps, y <- [2, -2]]

laws :: (Integral a) => [a] -> Bool
laws ps = and [(x `quot` y) * y + (x `rem` y) == x && (x `div` y) * y + (x `mod` y) == x | x <- ps, y <- [2, -2, 3, -3]]

main :: IO ()
main = do
  print (qs [7, -7 :: Int])
  print (qs [7, -7 :: Integer])
  print (laws [7, -7, 6, -6, 0 :: Int], laws [7, -7, 6, -6, 0 :: Integer])
  print ((-7) `quot` 2 :: Int, (-7) `div` 2 :: Int, quotRem (-7) 2 :: (Int, Int), divMod (-7) 2 :: (Int, Int))
  print (map even [-2, -1 :: Int], map odd [-2, -1 :: Integer])
  print (gcd 12 18 :: Int, gcd (-3) 6 :: Int, gcd (-3) (-6) :: Int, gcd 0 4 :: Int)
  print (lcm 4 6 :: Int, lcm 0 5 :: Int)
