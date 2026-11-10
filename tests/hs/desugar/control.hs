-- do (3.14) in the list and Maybe monads and in a monad of the program's own, a failed match calling fail; list
-- comprehensions (3.11) with generators, guards, let and a pattern that skips; sections (3.5) on both sides;
-- arithmetic sequences (3.10); if (3.6).
module Main (main) where

newtype Log a = Log (a, String)

instance Monad Log where
  return a = Log (a, "")
  Log (a, s) >>= f = let Log (b, t) = f a in Log (b, s ++ "[>>=]" ++ t)
  Log (_, s) >> Log (b, t) = Log (b, s ++ "[>>]" ++ t)

tell :: String -> Log ()
tell s = Log ((), s)

logOf :: Log a -> String
logOf (Log (_, s)) = s

pairsUpTo :: Int -> [(Int, Int)]
pairsUpTo n = do
  a <- [1 .. n]
  b <- [a .. n]
  return (a, b)

justs :: [Maybe Int] -> [Int]
justs ms = do
  Just x <- ms
  [x]

safeDiv :: Int -> Int -> Maybe Int
safeDiv _ 0 = Nothing
safeDiv a b = Just (a `div` b)

calc :: Maybe Int
calc = do
  a <- safeDiv 100 5
  let b = a + 1
  safeDiv b 3

main :: IO ()
main = do
  putStrLn (logOf (do { tell "a"; tell "b"; x <- return (1 :: Int); tell (show x) }))
  print (pairsUpTo 3)
  print (justs [Just 1, Nothing, Just 3])
  print (maybe 0 id calc)
  print [x * y | x <- [1 .. 4], odd x, let y = x + 1]
  print [a | Just a <- [Just 1, Nothing, Just (2 :: Int)]]
  print [(x, y) | x <- [10, 20 :: Int], y <- [1, 2 :: Int], y /= 2]
  print (map (`div` 2) [10, 11], map (10 -) [1, 2], map (subtract 1) [5])
  print (map (: []) [1, 2 :: Int])
  print ([1, 3 .. 9], [5, 4 .. 1], take 3 [7 ..], [2 .. 4] :: [Int])
  putStrLn (if 1 > (2 :: Int) then "yes" else "no")
