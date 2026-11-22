-- Report 2.2: small -> ascSmall | uniSmall | _; uniSmall -> any Unicode lowercase letter: α begins a varid.
module Main (main) where

main :: IO ()
main = print αβ
  where αβ = 1 :: Int
