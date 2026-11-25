-- Report: realToFrac = fromRational . toRational, so NaN does not survive Double -> Float.
module Main where
main = print (realToFrac (0/0 :: Double) :: Float)
