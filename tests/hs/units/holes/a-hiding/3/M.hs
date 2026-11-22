-- g, which Main hides, no longer exported: hiding it is an error (5.3.4).
module M (f, h) where

f :: Int
f = 1

g :: Int
g = 2

h :: Int
h = 3
