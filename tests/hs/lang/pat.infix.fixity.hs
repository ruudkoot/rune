-- rows: R9
-- Report 3.17: an infix constructor pattern resolves by the operators' fixities: x:y:zs is x:(y:zs), and with infixl 6 :+
-- and infixl 7 :*, a :+ b :* c is a :+ (b :* c).
module Main (main) where

infixl 6 :+
infixl 7 :*

data T = T :+ T | T :* T | L Int

f :: T -> String
f (a :+ b :* c) = "plus of times"
f _ = "other"

h :: [Int] -> Int
h (x : y : zs) = x + y + length zs
h _ = 0

main :: IO ()
main = do
  putStrLn (f (L 1 :+ (L 2 :* L 3)))
  putStrLn (f ((L 1 :+ L 2) :* L 3))
  print (h [1, 2, 3, 4])
