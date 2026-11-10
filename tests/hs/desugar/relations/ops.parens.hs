-- Operators resolved by fixity (3.4, 10.6) against the same program with every application of an operator in
-- parentheses (3.9: (e) is e): both desugar to the same Core.
module Main (main) where

infixr 5 +++
(+++) :: [Int] -> [Int] -> [Int]
xs +++ ys = foldr (:) ys xs

calc :: Int -> Int -> Int -> Int
calc a b c = ((a + (b * c)) - (a `div` (b ^ 2)))

chain :: [Int]
chain = (1 : (2 : ([3] +++ ([4] +++ (map negate [5, 6])))))

neg :: Int -> Int
neg x = ((- (x * 2)) + 1)

sections :: [Int]
sections = ((map (+ 1) [1]) ++ ((map (2 *) [3]) ++ (map ((subtract 1) . (* 2)) [4])))

cmp :: Int -> Bool
cmp x = (((x > 1) && (x < 10)) || (x == 0))

main :: IO ()
main = do
  print (calc 7 2 3)
  print chain
  print (neg 4)
  print sections
  print (length (filter cmp [0, 1, 5, 11]))
