# nofib's spectral/hartel/Fast2haskell.hs in Haskell 98, for rhc's corpus: the Report's Complex and Array for GHC's
# modules, and the bit operations by arithmetic on 64 bits for GHC's primitives. Its other definitions stay nofib's.
/^{-# OPTIONS -fglasgow-exts #-}$/d
/^import GHC\.Prim;$/d
/^import GHC\.Base;$/d
s/^import Data\.Complex;$/import Complex;/
s/^import Data\.Array;$/import Array;/
/^w2i x = word2Int# x;$/d
/^i2w x = int2Word# x;$/d
s/^land_i (I# x) (I# y) = .*$/land_i x y = bitop (\\a b -> a * b) x y;/
s/^lnot_i (I# x) = .*$/lnot_i x = negate x - 1;/
s/^lor_i (I# x) (I# y) = .*$/lor_i x y = bitop (\\a b -> a + b - a * b) x y;/
s/^lshift_i (I# x) (I# y) = .*$/lshift_i x n = x * 2 ^ n;/
/^rshift_i (I# x) (I# y) = .*$/c\
rshift_i x n = if x >= 0 then x `div` (2 ^ n) else (x + maxBound + 1) `div` (2 ^ n) + 2 ^ (63 - n);\
\
bitop :: (Int -> Int -> Int) -> Int -> Int -> Int;\
bitop g x y = go (64 :: Int) x y where {\
  go 0 _ _ = 0;\
  go n a b = g (a `mod` 2) (b `mod` 2) + 2 * go (n - 1) (a `div` 2) (b `div` 2) };
