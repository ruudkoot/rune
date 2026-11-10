-- HsLint's second inference: a module's default declaration (Report 4.3.4, R22): the first type of
-- the list in every class of the ambiguity, Double for Floating, Int for Integral and for a Num that
-- Rule 2 leaves, and one numeric class among them.
module Main (main) where

default (Int, Double)

x = sqrt 2
y = 2 ^ 3
z = 3

main :: IO ()
main = print (x, y, z, show 10)
