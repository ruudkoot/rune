-- rows: lib.r.ix.tuples lib.ix.inst.ixbool lib.ix.inst.ixordering
-- Report 15.1, 15.2 (overlay ov.ix.derived; M17's bottom probes on the literal Prelude): Ix of pairs, Bool, Ordering
-- and (), printed "as derived" and written out by rhc; the reference is the deriving clause on types of the same
-- shapes under other names, data P a b = P a b, data B = F | T, data O = L | E | G, data U = U (chapter 10, 15.2).
-- A marker, then the terms; the last is bottom.
module Main (main) where

import Ix

u :: Int
u = undefined

p :: Int -> Int -> (Int, Int)
p a b = (a, b)

main :: IO ()
main = do
  putStrLn "probe"
  print (range (p 0 0, p 1 2) == [p 0 0, p 0 1, p 0 2, p 1 0, p 1 1, p 1 2], index (p 0 0, p 1 2) (p 1 1))
  print (inRange (p 0 0, p 1 2) (p 2 u), inRange (p 0 0, p 1 2) (p 1 2), rangeSize (p 0 0, p 1 2))
  print (length (range (False, True)), index (False, True) True, inRange (False, False) True)
  print (length (range (LT, GT)), index (LT, GT) EQ, inRange (EQ, GT) LT, length (range ((), ())), index ((), ()) ())
  print (index (p 0 0, p 1 1) (p u 0))
