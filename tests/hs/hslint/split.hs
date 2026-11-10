-- HsLint's second inference: a signature does not cut a declaration group, and each use of a signed
-- variable has its declared type (R21(c), Typing Haskell in Haskell 11.6.3's example), so g is
-- inferred with f's signature and is Ord a => a -> Bool.
module Main (main) where

f :: Eq a => a -> Bool
f x = (x == x) || g True
g y = (y <= y) || f True

main :: IO ()
main = print (f 'c', g 'd')
