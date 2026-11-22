-- HsLint's second inference: a simple pattern binding is 4.5.5's, one variable, guards allowed, and
-- `(y)` and `~z` are not simple (R18); each is restricted without a signature, so its type is
-- fixed by its uses in the module or defaulted where it ends (Rule 2).
module Main (main) where

x | True = 1
(y) = 2
~z = 3

main :: IO ()
main = print (x :: Int, y + 1.5, z)
