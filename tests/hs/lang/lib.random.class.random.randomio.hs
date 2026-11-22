-- rows: lib.r.random.io lib.r.random.setstdgen lib.r.random.newstdgen lib.r.random.getstdrandom lib.r.random.rolldice lib.random.class.random.randomrio lib.random.newstdgen lib.random.setstdgen lib.random.getstdgen lib.random.getstdrandom
-- Report 27: the global generator: setStdGen and getStdGen, randomIO and randomRIO from it, newStdGen splitting it.
module Main (main) where

import Random

main :: IO ()
main = do
  setStdGen (mkStdGen 7)
  g <- getStdGen
  x <- randomRIO (1, 6 :: Int)
  setStdGen g
  y <- randomRIO (1, 6 :: Int)
  z <- getStdRandom (randomR (1, 6 :: Int))
  b <- randomIO :: IO Bool
  n <- newStdGen
  print (x == y, all (\v -> v >= 1 && v <= 6) [x, y, z], b || not b, fst (randomR (2, 2 :: Int) n))
