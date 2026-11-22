-- rows: lib.random.class.randomgen.genrange lib.random.class.randomgen.next lib.random.class.randomgen.split lib.r.random.genrange.default
-- Report 27: a user RandomGen with next and split only: genRange defaults to (minBound, maxBound) of Int; randomR draws
-- from it.
module Main (main) where

import Random

newtype G = G Int
instance RandomGen G where
  next (G n) = (n, G (n + 1))
  split (G n) = (G (2 * n), G (2 * n + 1))

main :: IO ()
main = do
  print (genRange (G 0) == (minBound, maxBound), fst (next (G 5)))
  print (all (\x -> x >= 1 && x <= 6) (take 20 (randomRs (1, 6 :: Int) (G 0))))
