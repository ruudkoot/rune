-- Report 4.2.3: d2 bottom is bottom.
module Main (main) where

data D1 = D1 Int
data D2 = D2 !Int
type S = Int
newtype N = N Int

d1 :: D1 -> Int
d1 (D1 i) = 42

d2 :: D2 -> Int
d2 (D2 i) = 42

s :: S -> Int
s i = 42

n :: N -> Int
n (N i) = 42

main :: IO ()
main = print (d2 undefined)
