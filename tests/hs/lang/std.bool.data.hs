-- rows: std.bool.read std.bool.show std.bool.eq std.bool.ord std.bool.enum std.bool.bounded std.bool.ops std.bool.otherwise
-- Report 6.1.1: data Bool = False | True deriving (Read, Show, Eq, Ord, Enum, Bounded), &&, ||, not and otherwise.
module Main (main) where

f :: Int -> String
f x | x > 0 = "pos"
    | otherwise = "other"

main :: IO ()
main = do
  print (False < True, fromEnum True, minBound :: Bool, maxBound :: Bool)
  print (read "True" :: Bool, show False, True == True, compare False True)
  print [False ..]
  print [(a && b, a || b, not a) | a <- [False, True], b <- [False, True]]
  print (otherwise == True, f 0)
