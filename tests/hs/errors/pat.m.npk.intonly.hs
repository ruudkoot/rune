-- Report 3.17.2: "Only integer literals are allowed for k" in n+k: not n+1.5.
module Main (main) where

f :: Double -> Double
f (n+1.5) = n
f _ = 0

main :: IO ()
main = return ()
