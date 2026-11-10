-- rows: R15
-- Report 3.17.2 (R15, the owner's call of 2026-11-10): in an n+k pattern "k is a positive integer literal", so n+0 is
-- refused, by the prose over the grammar's integer, as Hugs refuses it ("Integer k in (n+k) pattern must be > 0");
-- GHC and nhc98 accept it. 3.17.3's rule (s) (tr.case.s) is read with that k.
module Main (main) where

f :: Int -> Int
f (n+0) = n
f _ = 0

main :: IO ()
main = print (f 1)
