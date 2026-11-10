-- rows: std.int.range std.int.bounded std.integer.arbitrary std.num.table.integer std.num.table.int
-- Report 6.3.7: Bounded at (), Bool, Ordering, Char and tuples; 6.4: Int covers at least -2^29 to 2^29-1 and its bounds
-- are reached; Integer is of any size; quot at Integer and Int.
module Main (main) where

main :: IO ()
main = do
  print (minBound :: (), maxBound :: Bool, minBound :: Ordering, minBound :: Char)
  print ((minBound :: Int) <= - 2 ^ 29, (maxBound :: Int) >= 2 ^ 29 - 1)
  print ((maxBound :: Int) - 1 + 1 == maxBound, (minBound :: Int) + 1 - 1 == minBound)
  print (2 ^ 1000 :: Integer)
  print (7 `quot` 2 :: Integer, 7 `quot` 2 :: Int)
