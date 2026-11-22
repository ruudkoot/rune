-- rows: dec.sig.polyrec.nosig.int
-- Report 4.4.1: a signature supports polymorphic recursion, the Report's T and f; without one f has type T Int -> Int,
-- usable at T Int.
module Main (main) where

data T a = K (T Int) (T a)

f :: T a -> a
f (K x y) = if f x == 1 then f y else undefined

g (K x y) = if g x == 1 then g y else undefined

useG :: T Int -> Int
useG = g

main :: IO ()
main = return ()
