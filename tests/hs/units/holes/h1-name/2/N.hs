-- H1 (E13, GHC's case): N exports f now, and Main's f is ambiguous (5.5.2).
module N where

g :: Int
g = 1

f :: Int
f = 3
