-- Report 9.5: pat10 -> gcon apat1 ... apatk (arity gcon = k) and apat -> gcon (arity gcon = 0): Just takes one
-- pattern, here none.
module Main (main) where

f :: Maybe Int -> Int
f Just = 1
f _ = 0

main :: IO ()
main = return ()
