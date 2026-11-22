-- rows: lib.random.export.stdgen lib.random.export.mkstdgen lib.random.export.randomrandomcrandomrcrandomscrandomrscrandomiocr lib.random.export.getstdrandom lib.random.export.getstdgen lib.random.export.setstdgen lib.random.export.newstdgen
-- Report 27: module Random exports each of these: an explicit import of every one compiles, and each name is used.
module Main (main) where

import Random (RandomGen(next, split, genRange), StdGen, mkStdGen, Random( random, randomR, randoms, randomRs, randomIO, randomRIO ), getStdRandom, getStdGen, setStdGen, newStdGen)

c0 :: (RandomGen a) => a -> ()
c0 _ = ()
s0_0 _ = next
s0_1 _ = split
s0_2 _ = genRange

t1 :: StdGen -> ()
t1 _ = ()

v2 _ = mkStdGen

c3 :: (Random a) => a -> ()
c3 _ = ()
s3_0 _ = random
s3_1 _ = randomR
s3_2 _ = randoms
s3_3 _ = randomRs
s3_4 _ = randomIO
s3_5 _ = randomRIO

v4 _ = getStdRandom

v5 _ = getStdGen

v6 _ = setStdGen

v7 _ = newStdGen

main :: IO ()
main = return ()
