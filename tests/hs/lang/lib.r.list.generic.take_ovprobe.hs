-- rows: lib.r.list.generic.drop lib.r.list.generic.splitat
-- Report 17.9 (overlay ov.list.generic, erratum e.2008.09.generic; M17's bottom probes on the literal Prelude):
-- genericTake, genericDrop and genericSplitAt as the erratum writes them; the reference is the printed code under
-- other names. They agree on the first line; on the second the printed code calls error at a negative count, and on
-- the last it gives 0 (the erratum's differences: a count of at most 0 takes nothing, and is looked at first). A
-- marker, then the terms; the last is bottom.
module Main (main) where

import List

n :: Integer
n = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (genericTake (2 :: Integer) "abc", genericDrop (1 :: Integer) "abc", genericSplitAt (1 :: Integer) "abc",
         genericTake (5 :: Integer) "ab", take 2 (genericTake (3 :: Integer) ('x' : 'y' : undefined)))
  print (genericTake (-1 :: Integer) "abc", genericDrop (-1 :: Integer) "abc", genericSplitAt (-1 :: Integer) "abc")
  print (length (genericTake n ""))
