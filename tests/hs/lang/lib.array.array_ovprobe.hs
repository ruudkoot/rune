-- rows: lib.array.bang lib.array.bounds lib.array.inst.functorarraya lib.r.array.strict.indices lib.r.array.strict.values
-- Report 16.1, 16.4 (overlay ov.array.representation; M17's bottom probes on the literal Prelude): array, listArray,
-- (!), bounds and fmap over rhc's representation, an Arr of the elements; the reference is the printed module's
-- MkArray of the bounds and a function, its code copied under other names. A marker, then the terms; the last is
-- bottom.
module Main (main) where

import Array

c :: Char
c = undefined

i :: Int
i = undefined

b :: Int -> Int -> (Int, Int)
b x y = (x, y)

main :: IO ()
main = do
  putStrLn "probe"
  print (listArray (b 1 3) "abc" ! 2, listArray (b 1 3) ['a', c, 'c'] ! 3, array (b 1 2) [(1, 'a'), (2, c)] ! 1)
  print (bounds (array (b 1 2) [(1, c), (2, c)]), elems (listArray (b 0 2) "xyz"), (array (b 1 1) [(1, c)]) `seq` ())
  print (array (b 1 2) [(1, 'a'), (1, 'b'), (2, 'c')] ! 2, fmap succ (listArray (b 0 1) ['a', c]) ! 0)
  print (bounds (fmap succ (listArray (b 0 1) "ab")), elems (listArray (b 1 2) "pq" // [(2, 'r')]))
  print (array (b 1 2) [(i, 'a')] ! 1)
