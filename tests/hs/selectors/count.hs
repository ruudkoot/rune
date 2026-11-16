-- D17's count: a program of selectors -- unzip's lazy pattern, lines' and words' pattern bindings, a let of a pair in
-- a recursion -- each a suspension the collector reduces to its tuple's field once the tuple is evaluated (Wadler's
-- rule, runtime/gc/gc.h), which the program then does not ENTER. Whether one is reduced must not depend on the order
-- in which a collection reaches the selector and its tuple, which differs between the interpreter's frames and
-- compiled code's: interpreted, at tier 1, at tier 2 and under --deopt-stress the program counts the same
-- instructions at the default nursery (hs/selectors/count, Oracles.jitOneWith).
module Main (main) where

pairs :: Int -> [(Int, Int)]
pairs n = [(i, i * 3) | i <- [1 .. n]]

parts :: [Int] -> ([Int], [Int])
parts [] = ([], [])
parts (x : xs) = let (es, os) = parts xs in if even x then (x : es, os) else (es, x : os)

polarish :: Double -> (Double, Double)
polarish x = (x * cos x, x * sin x)

fields :: String -> [String]
fields s = let (a, rest) = break (== ',') s in a : case rest of { [] -> []; (_ : r) -> fields r }

main :: IO ()
main = do
  let (as, bs) = unzip (pairs 20000)
  print (sum as, sum bs)
  let text = concat [show i ++ (if i `mod` 7 == 0 then "\n" else " ") | i <- [1 .. 8000 :: Int]]
  print (length (lines text), length (words text))
  let (es, os) = parts [1 .. 12000]
  print (length es, sum os)
  print (length (fields (concat (replicate 6000 "ab,cd"))))
  let (cs, ss) = unzip (map polarish [0, 0.25 .. 3000])
  print (round (sum cs) :: Int, round (sum ss) :: Int)
  let fr = [let (n, f) = properFraction x in fromIntegral (n :: Int) + f | x <- [0.5, 1.75 .. 8000 :: Double]]
  print (round (sum fr) :: Int)
