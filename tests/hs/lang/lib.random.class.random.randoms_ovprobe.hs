-- rows: lib.random.class.randomgen.genrange lib.random.class.random.randomrs
-- Report 27.1, 27.2 (overlay ov.random.defaults; the bottom probes of M17, on M18's Random): the class defaults the
-- text prints and the module's code leaves out, written into the classes; the reference is the text's genRange g =
-- (minBound,maxBound), randoms g = x : randoms g' where (x,g') = random g, and randomRs "similar", under other
-- names, on a generator of the program's that counts. A marker, then the terms; the last is bottom.
module Main (main) where

import Random

newtype G = G Int

instance RandomGen G where
  next (G n) = (n, G (n + 1))
  split (G n) = (G n, G (n + 1))

g :: G
g = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (genRange g == (minBound, maxBound), length (take 3 (randoms (G 0) :: [Int])))
  print (take 3 (randomRs (0, 9 :: Int) (G 5)) == take 3 (map fst (iterate (\(_, h) -> randomR (0, 9) h) (randomR (0, 9) (G 5)))))
  print (length (take 2 (randoms g :: [Int])))
  print (head (randoms g :: [Int]))
