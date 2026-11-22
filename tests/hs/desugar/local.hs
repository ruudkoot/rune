-- let and where (3.12, 4.5): a binding used at two types, bindings that call each other, a pattern binding with a
-- wildcard, a self-referring list, and a function of a where that is lazy in what it is not given.
module Main (main) where

pairUp :: (Int, String)
pairUp = let ident x = x in (ident 3, ident "three")

evens :: Int -> [Int]
evens n = take n (filter isEven [0 ..])
  where
    isEven 0 = True
    isEven k = isOdd (k - 1)
    isOdd 0 = False
    isOdd k = isEven (k - 1)

firstOfThree :: (Int, Int, Int) -> Int
firstOfThree t = let (a, _, _) = t in a

ones :: [Int]
ones = let xs = 1 : xs in xs

lazyWhere :: Int -> Int
lazyWhere n = if n > 0 then n else boom
  where boom = error "not reached"

main :: IO ()
main = do
  print (fst pairUp)
  putStrLn (snd pairUp)
  print (evens 4)
  print (firstOfThree (9, undefined, undefined))
  print (take 3 ones)
  print (lazyWhere 5)
  print (let (p, q) = (q + 1, 10) in p :: Int)
