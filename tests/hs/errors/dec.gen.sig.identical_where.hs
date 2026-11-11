-- rows: R21
-- Report 4.5.1 and 4.5.2 (R21(c), the lead's ruling 55): f and g are one declaration group only through g's where,
-- whose p uses f, for a signature cuts no group; so the contexts of their signatures, Ord d and none, must be
-- identical up to renaming, and are not: refused. GHC and Hugs accept it by Haskell 2010's groups (GHC's tcfail071
-- is this shape).
module Main (main) where

f :: Ord d => d -> d
f c = g c

g :: e -> e
g c = c
  where p = f (1 :: Int)

main :: IO ()
main = print (f 'x')
