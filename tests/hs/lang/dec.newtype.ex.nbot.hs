-- rows: dec.newtype.ex.nn dec.newtype.ex.d1d1 dec.newtype.ex.s dec.newtype.ex.d1notbot dec.strict.unflagged tr.dec.strict.partial tr.dec.strict.pattern
-- Report 4.2.3, the Report's examples: n bottom, n (N bottom), d1 (D1 bottom) and s bottom are 42, D1 bottom is a value;
-- 4.2.1: an unflagged field is lazy, a strict constructor partly applied is a function, and matches as any other.
module Main (main) where

data D1 = D1 Int
data D2 = D2 !Int
type S = Int
newtype N = N Int

d1 :: D1 -> Int
d1 (D1 i) = 42

d2 :: D2 -> Int
d2 (D2 i) = 42

s :: S -> Int
s i = 42

n :: N -> Int
n (N i) = 42

data K = K !Int !Int

main :: IO ()
main = do
  print [n undefined, n (N undefined), d1 (D1 undefined), s undefined]
  print (seq (D1 undefined) (1 :: Int), case D1 undefined of D1 _ -> (1 :: Int), seq (K undefined) (1 :: Int), case K 1 2 of K a b -> a + b)
