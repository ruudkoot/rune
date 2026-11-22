-- rows: lib.r.random.randomr lib.r.random.random.bounded lib.r.random.random.fractional lib.r.random.random.integer lib.r.random.plural lib.r.random.instances lib.r.random.mkstdgen lib.r.random.genrange.lazy lib.r.random.next lib.r.random.split lib.r.random.split.warning lib.r.random.stdgen.instance lib.r.random.stdgen.range lib.random.data.stdgen lib.random.inst.randomgenstdgen lib.random.inst.showstdgen lib.random.inst.readstdgen lib.random.inst.randomint lib.random.inst.randominteger lib.random.inst.randomfloat lib.random.inst.randomdouble lib.random.inst.randombool lib.random.inst.randomchar lib.random.class.random lib.random.class.random.randomr lib.random.class.random.random lib.random.class.random.randomrs lib.random.class.random.randoms
-- Report 27: StdGen's genRange is a range of at least 2^30 - 1, lazy in its argument; next stays in it; split gives two
-- generators whose sequences differ; randomR stays in its range at each type; randoms and randomRs are infinite;
-- read of show gives a generator; the values are the implementation's, so only properties are printed.
module Main (main) where

import Random

g0 :: StdGen
g0 = mkStdGen 42

main :: IO ()
main = do
  let (lo, hi) = genRange g0
  print (lo < hi, toInteger hi - toInteger lo >= 2 ^ 30 - 1, fst (genRange (undefined :: StdGen)) == lo)
  print (and [n >= lo && n <= hi | n <- take 100 (map fst (tail (iterate (next . snd) (0, g0))))])
  let (a, b) = split g0
  print (take 5 (randoms a :: [Int]) /= take 5 (randoms b), take 5 (randoms (snd (split g0)) :: [Int]) /= take 5 (randoms (snd (split (fst (split g0))))))
  print (all (\x -> x >= 3 && x <= 9) (take 100 (randomRs (3, 9 :: Int) g0)), all (\x -> x >= 0 && x <= 1) (take 100 (randomRs (0, 1 :: Double) g0)))
  print (all (\x -> x >= -5 && x <= 5) (take 50 (randomRs (-5, 5 :: Integer) g0)), all (`elem` "abc") (take 50 (randomRs ('a', 'c') g0)))
  print (length (take 3 (randoms g0 :: [Bool])), all (\x -> x >= 0 && x < 1) (take 50 (randoms g0 :: [Float])))
  print (take 5 (randoms (read (show g0) :: StdGen) :: [Int]) == take 5 (randoms g0), fst (randomR (7, 7 :: Int) g0))
