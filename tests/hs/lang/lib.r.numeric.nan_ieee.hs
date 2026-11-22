-- rows: lib.r.numeric.signed.float lib.r.numeric.readfloat.special
-- Report 14.4: formatRealFloat shows NaN as "NaN" and the infinities as "Infinity" and "-Infinity", and a negative
-- zero with its sign, at IEEE Double and Float; readFloat reads "NaN" and "Infinity".
module Main (main) where

import Numeric

main :: IO ()
main = do
  print (showEFloat Nothing (-0.0 :: Double) "", showFFloat Nothing (-0.0 :: Double) "", showGFloat (Just 2) (-0.0 :: Double) "")
  print (map (\x -> showEFloat Nothing x "") [0 / 0, 1 / 0, -1 / 0 :: Double], map (\x -> showFFloat (Just 2) x "") [0 / 0, 1 / 0, -1 / 0 :: Double])
  print (map (\x -> showGFloat Nothing x "") [0 / 0, 1 / 0, -1 / 0 :: Float])
  print (map (isNaN . fst) (readFloat "NaN" :: [(Double, String)]), map fst (readFloat "Infinity rest" :: [(Double, String)]), map snd (readFloat "Infinity rest" :: [(Double, String)]))
