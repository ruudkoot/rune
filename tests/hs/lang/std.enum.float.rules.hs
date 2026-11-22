-- rows: std.enum.float.neg std.enum.float.to.nonempty R39
-- Report 6.3.4, 8 (numericEnumFromTo and kin): at Float and Double the sequence goes on while the element is at most the
-- limit plus half the step: [1.0..2.5] is [1.0,2.0,3.0], and [1.0..0.5] is [1.0].
module Main (main) where

main :: IO ()
main = do
  print ([1.0 .. 2.5] :: [Double])
  print ([3.0, 2.0 .. 0.5] :: [Double])
  print ([1.0 .. 0.5] :: [Double])
  print ([1.0 .. 2.5] :: [Float])
