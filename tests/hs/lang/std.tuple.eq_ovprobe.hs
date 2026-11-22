-- rows: std.tuple.ord std.tuple.bounded
-- Report 6.1.4, 8 (overlay ov.prelude.tuples; M17's bottom probes on the literal Prelude): Eq, Ord and Bounded of
-- pairs and triples, which the Report declares by deriving clauses and rhc writes out; the reference is those clauses
-- under other names, data P a b = P a b and data T a b c = T a b c deriving (Eq, Ord, Bounded) (chapter 10). A
-- marker, then the terms; the last is bottom.
module Main (main) where

u :: Int
u = undefined

p :: Int -> Int -> (Int, Int)
p a b = (a, b)

t :: Int -> Int -> Int -> (Int, Int, Int)
t a b c = (a, b, c)

main :: IO ()
main = do
  putStrLn "probe"
  print (p 1 u == p 2 0, compare (p 1 u) (p 2 0), p 1 2 < p 1 3, snd (max (p 1 u) (p 2 0)))
  print (t 1 2 u == t 1 3 0, compare (t 1 2 u) (t 1 3 0))
  print (fst (minBound :: (Bool, Ordering)) == False, snd (maxBound :: (Bool, Ordering)) == GT)
  print (p u 1 == p 0 1)
