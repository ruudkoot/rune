-- rows: pre.inst.ordinteger pre.inst.numinteger pre.inst.realinteger pre.inst.integralinteger pre.inst.enuminteger
-- Report 8: the instances of Integer: Eq, Ord, Num, Real, Integral and Enum, each method on sample values, and beyond Int.
module Main (main) where

main :: IO ()
main = do
  print (3 == (3 :: Integer), 3 /= (3 :: Integer), compare 2 (3 :: Integer), max 2 (3 :: Integer), min 2 (3 :: Integer))
  print (2 + 3 :: Integer, 2 - 3 :: Integer, 2 * 3 :: Integer, negate 3 :: Integer, abs (-3) :: Integer)
  print (signum (-3) :: Integer, fromInteger 7 :: Integer, toRational (3 :: Integer) == 3, toInteger (5 :: Integer))
  print (quotRem (-7) 2 :: (Integer, Integer), divMod (-7) 2 :: (Integer, Integer), quot 7 (-2) :: Integer, rem 7 (-2) :: Integer)
  print (div 7 (-2) :: Integer, mod 7 (-2) :: Integer, succ 1 :: Integer, pred 1 :: Integer, fromEnum (4 :: Integer))
  print (toEnum 4 :: Integer, [1 .. 4] :: [Integer], [1, 3 .. 9] :: [Integer], take 2 [7 ..] :: [Integer], take 2 [7, 5 ..] :: [Integer])
  print (2 ^ 70 + 1 :: Integer, divMod (- (2 ^ 70)) 3 :: (Integer, Integer))
