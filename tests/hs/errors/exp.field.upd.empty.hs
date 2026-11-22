-- Report 3.15.3: an update has at least one binding: not r {}.
module Main (main) where

data R = R { f :: Int }

r :: R
r = R { f = 1 }

main :: IO ()
main = print (f (r {}))
