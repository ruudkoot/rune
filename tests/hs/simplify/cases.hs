-- Cases a simplifier knows the answer of (M23): a known constructor, a
-- case of a case, guards with || and &&, the same variable tested twice as
-- a match backtracks, literals of Int, Char and Integer, and strings.
-- fuel: every lint holds and it prints the same whatever rewrite it stops after
module Main where

data T = A Int | B Bool | C

classify :: T -> String
classify t = case t of
  A n | n > 0 || n == -1 -> "positive or minus one"
      | n == 0 && True -> "zero"
  A _ -> "negative"
  B b | not b -> "false"
  B _ -> "true"
  C -> "c"

grade :: Int -> Char
grade n
  | n >= 90 = 'A'
  | n >= 80 = 'B'
  | otherwise = 'C'

digits :: Integer -> String
digits 0 = "zero"
digits 1 = "one"
digits n = if even n then "even" else "odd"

first :: [a] -> Maybe a
first xs = case xs of
  [] -> Nothing
  (y:_) -> Just y

vowel :: Char -> Bool
vowel c = c `elem` "aeiou"

main :: IO ()
main = do
  mapM_ (putStrLn . classify) [A 3, A (-1), A 0, A (-5), B False, B True, C]
  putStrLn (map grade [95, 85, 75])
  print (map digits [0, 1, 2, 3, 12345678901234567890])
  print (first "abc", first ([] :: [Int]), fmap (+ 1) (first [10 :: Int]))
  print (filter vowel "simplifier", case "ab" of ('a':_) -> 1; _ -> 2 :: Int)
  print (let x = Just (5 :: Int) in case x of Just n -> n; Nothing -> 0)
