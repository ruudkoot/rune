-- rows: pre.inst.ordchar pre.inst.enumchar pre.inst.boundedchar
-- Report 8: the instances of Char: Eq, Ord, Enum and Bounded, each method on sample values.
module Main (main) where

main :: IO ()
main = do
  print ('a' == 'a', 'a' /= 'b', compare 'a' 'b', max 'a' 'b', min 'a' 'b')
  print ('a' < 'b', 'b' <= 'a', 'b' > 'a', 'a' >= 'a')
  print (succ 'a', pred 'b', toEnum 65 :: Char, fromEnum 'A', minBound :: Char)
  print (['a' .. 'e'], ['a', 'c' .. 'i'], take 3 ['x' ..], take 3 ['a', 'b' ..])
