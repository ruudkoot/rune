-- rows: def.implicit def.literal.exponent def.pick.separate mr.rule2.defaulted prog.main.value def.cond.numeric.each
-- Report 4.3.4: an ambiguous type defaults by default (Integer, Double): 1 at Integer, 2^70 exactly, 1.5 at Double, the
-- exponent of ^ at Integer, integers and fractions apart in one expression, at each numeric class.
module Main (main) where

x = 2 ^ 70

main :: IO ()
main = do
  print 1
  print x
  print 1.5
  let y = 3 :: Int in print (y ^ 2)
  print (2 ^ 10, 1 / 2)
  print (fromIntegral (3 :: Int), 3 / 2, sqrt 4, truncate 2.5)
  print (toRational 3, 7 `div` 2, floatDigits 1.0, succ 1)
