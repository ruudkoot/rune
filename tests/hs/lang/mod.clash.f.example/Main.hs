-- Report 5.5.2's example: f x = Prelude.sin (F.sin x), each reference qualified.
module Main (main) where

import qualified F

f :: Double -> Double
f x = Prelude.sin (F.sin x)

main :: IO ()
main = print (f 0)
