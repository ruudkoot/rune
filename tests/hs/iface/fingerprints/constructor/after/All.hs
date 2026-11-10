-- A constructor added: the type moves with its constructors, and a value whose type mentions it; another stays.
module All (T(..), k, n) where

data T = X | Y | Z

k :: T -> Int
k _ = 1

n :: Int
n = 2
