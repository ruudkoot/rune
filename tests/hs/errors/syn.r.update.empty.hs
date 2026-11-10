-- Report 9.5: aexp -> aexp<qcon> { fbind1 , ... , fbindn } (labeled update, n >= 1): not x {}.
module Main (main) where

data R = R { a :: Int }

r :: R
r = R { a = 1 }

main :: IO ()
main = print (a (r {}))
