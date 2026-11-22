-- rows: lib.random.newstdgen lib.random.setstdgen lib.random.getstdgen lib.random.getstdrandom
-- Report 27: each function of Random at its Report type, by a signature; running it does nothing.
module Main (main) where

import Random

mkStdGen' :: Int -> StdGen
mkStdGen' = mkStdGen

newStdGen' :: IO StdGen
newStdGen' = newStdGen

setStdGen' :: StdGen -> IO ()
setStdGen' = setStdGen

getStdGen' :: IO StdGen
getStdGen' = getStdGen

getStdRandom' :: (StdGen -> (a, StdGen)) -> IO a
getStdRandom' = getStdRandom

main :: IO ()
main = putStrLn "typed"
