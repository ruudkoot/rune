-- More patterns (3.17): n+k (rule (s)), characters and strings (rule (h), a string as its list of characters), list
-- patterns, nested constructors, infix constructors, and an expression's signature (3.16).
module Main (main) where

data Op = Int :+: Int | Neg Op

fact :: Int -> Int
fact 0 = 1
fact (n + 1) = (n + 1) * fact n

pred' :: Integer -> Integer
pred' (n + 1) = n
pred' _ = -1

vowel :: Char -> String
vowel 'a' = "a vowel"
vowel 'e' = "a vowel"
vowel _ = "not one"

greeting :: String -> String
greeting "hello" = "hi"
greeting ('h' : rest) = "h then " ++ rest
greeting "" = "nothing"
greeting _ = "?"

shape :: [Int] -> String
shape [] = "empty"
shape [_] = "one"
shape [a, b] | a == b = "pair of a kind"
shape [_, _] = "pair"
shape (_ : _ : _ : _) = "many"

eval :: Op -> Int
eval (a :+: b) = a + b
eval (Neg (Neg o)) = eval o
eval (Neg o) = negate (eval o)

poly :: (Int, Integer)
poly = ((3 :: Num a => a) + 1, (3 :: Num a => a) * 2)

main :: IO ()
main = do
  print (fact 5)
  print (pred' 10, pred' 0)
  putStrLn (vowel 'e')
  putStrLn (vowel 'z')
  putStrLn (greeting "hello")
  putStrLn (greeting "hat")
  putStrLn (greeting "")
  putStrLn (greeting "x")
  putStrLn (unwords (map shape [[], [1], [2, 2], [2, 3], [1, 2, 3]]))
  print (eval (Neg (Neg (1 :+: 2))), eval (Neg (3 :+: 4)))
  print poly
  print ((2 :: Int) + (3 :: Int) :: Int)
