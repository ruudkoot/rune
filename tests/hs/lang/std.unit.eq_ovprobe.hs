-- rows: std.unit.ord std.unit.enum std.unit.bounded
-- Report 6.1.5, 8 (overlay ov.prelude.unit; M17's bottom probes on the literal Prelude): ()'s instances, which the
-- Report declares by its deriving clause and rhc writes out; the reference is that clause on a type of one
-- constructor, data U = U deriving (Eq, Ord, Enum, Bounded) (chapter 10), the Report's line under another name.
-- A marker, then the terms; the last is bottom.
module Main (main) where

u :: ()
u = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (() == (), () /= (), compare () (), () < (), () >= ())
  print (fromEnum (), length [minBound .. maxBound :: ()], length [() ..], length (take 3 [(), () ..]))
  print (fromEnum (toEnum 0 :: ()), fromEnum (max () ()), fromEnum (minBound :: ()))
  print (u == ())
