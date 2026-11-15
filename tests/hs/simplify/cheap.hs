-- Cheap eagerness's bottom probes (D51; the simplifier's core-cheap, at -O2
-- unless --no-cheap-eagerness): a let of a cheap and total expression is
-- made a case, its value made at once; one that may raise or loop stays a
-- suspension, made only where it is demanded. Each of a to g is bound and
-- never demanded (n is 1), so one made at once would stop the program here:
-- Int's arithmetic, which raises on overflow (D22), div by zero, chr out of
-- range, head of nothing, error, a loop, and a case of a suspension that
-- is bottom. x, y and z are cheap and total, and demanded.
module Main where

import Char (ord, chr)

probe :: Int -> Double -> Int -> [String]
probe n d k =
  let a = n + maxBound
      b = n `div` k
      c = chr (n + 2000000)
      e = head (drop n [] :: [Int])
      f = error "f demanded" :: String
      g = length [1 :: Int ..]
      h = case (undefined :: Maybe Int) of { Just v -> v < n; Nothing -> False }
      x = d * 2.5 + 1.0
      y = d < 3.0
      z = ord 'a' < n
  in [show x, show y, show z]
     ++ (if n > 100 then [show a, show b, show [c], show e, f, show g, show h] else [])

main :: IO ()
main = do
  mapM_ putStrLn (probe 1 1.5 0)
  print (sum [ if fromIntegral i * 0.5 < (3.0 :: Double) then 1 else 0 | i <- [1 .. 20 :: Int] ] :: Int)
