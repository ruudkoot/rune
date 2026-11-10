-- rows: pre.inst.ordint pre.inst.numint pre.inst.realint pre.inst.integralint pre.inst.enumint pre.inst.boundedint pre.r.inst.omitted
-- Report 8: the instances of Int, which the Report omits as binding primitives (but they exist): Eq, Ord, Num, Real,
-- Integral, Enum and Bounded, each method on sample values.
module Main (main) where

main :: IO ()
main = do
  print (3 == (3 :: Int), 3 /= (3 :: Int), compare 2 (3 :: Int), max 2 (3 :: Int), min 2 (3 :: Int))
  print (2 + 3 :: Int, 2 - 3 :: Int, 2 * 3 :: Int, negate 3 :: Int, abs (-3) :: Int)
  print (signum (-3) :: Int, fromInteger 7 :: Int, toRational (3 :: Int) == 3, toInteger (5 :: Int))
  print (quotRem (-7) 2 :: (Int, Int), divMod (-7) 2 :: (Int, Int), quot 7 (-2) :: Int, rem 7 (-2) :: Int)
  print (div 7 (-2) :: Int, mod 7 (-2) :: Int, succ 1 :: Int, pred 1 :: Int, fromEnum (4 :: Int))
  print (toEnum 4 :: Int, [1 .. 4] :: [Int], [1, 3 .. 9] :: [Int], take 2 [7 ..] :: [Int], take 2 [7, 5 ..] :: [Int])
  print ((minBound :: Int) < 0, (maxBound :: Int) > 0, (maxBound :: Int) + 0 == maxBound)
