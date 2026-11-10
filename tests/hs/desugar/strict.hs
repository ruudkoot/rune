-- Strict fields (4.2.1): the constructor as a function forces its strict arguments, so a value built of a bottom is
-- bottom, but a partial application is a value; a match on it is a match as on any constructor.
module Main (main) where

data S = S !Int !Int
data L = L !Int Int

sumS :: S -> Int
sumS (S a b) = a + b

lazySecond :: L -> Int
lazySecond (L a _) = a

main :: IO ()
main = do
  print (sumS (S 1 2))
  print (seq (S undefined) (1 :: Int))
  print (lazySecond (L 3 undefined))
  print (case L 4 undefined of L a _ -> a)
  print (seq (S 1 undefined) (2 :: Int))
