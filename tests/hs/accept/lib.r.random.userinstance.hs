-- Report 27: a user instance of Random works with the class's methods.
module Main (main) where

import Random

data Coin = Heads | Tails deriving (Show, Enum, Bounded)

instance Random Coin where
  randomR (a, b) g = let (n, g') = randomR (fromEnum a, fromEnum b) g in (toEnum n, g')
  random g = randomR (minBound, maxBound) g

flips :: [Coin]
flips = take 10 (randoms (mkStdGen 3))

main :: IO ()
main = print (length flips)
