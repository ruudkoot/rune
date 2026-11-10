-- rows: lib.r.random.read.finite lib.r.random.read.distinct lib.r.random.readshow R49
-- Report 27 (readings.md R49's seed): StdGen's Read succeeds on any string, the empty one and arbitrary text, consumes a
-- finite part of an infinite one, and different strings likely give different generators; read of show gives the
-- same sequence.
module Main (main) where

import Random

seq5 :: StdGen -> [Int]
seq5 g = take 5 (randoms g)

main :: IO ()
main = do
  print (not (null (reads "" :: [(StdGen, String)])), not (null (reads "any text" :: [(StdGen, String)])))
  print (case reads (cycle "ab") :: [(StdGen, String)] of { ((_, rest) : _) -> take 2 rest == take 2 rest; [] -> False })
  let g1 = fst (head (reads "alpha" :: [(StdGen, String)]))
      g2 = fst (head (reads "beta" :: [(StdGen, String)]))
  print (seq5 g1 /= seq5 g2, seq5 (read (show g1)) == seq5 g1)
