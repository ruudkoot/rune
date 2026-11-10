-- rows: std.ord.default.le std.ord.default.lt std.ord.default.ge std.ord.default.gt std.ord.default.max std.ord.default.min std.ord.minmax std.ord.basic std.ord.derive std.ord.minimal
-- Report 6.3.2: Ord's defaults from <= alone or compare alone; max x y is y and min x y is x when x <= y, which tells
-- apart values that are equal but distinguishable; the Prelude's types and a derived instance.
module Main (main) where

data O = O Int Char

instance Eq O where
  O a _ == O b _ = a == b

instance Ord O where
  O a _ <= O b _ = a <= b

data P = P Int

instance Eq P where
  P a == P b = a == b

instance Ord P where
  compare (P a) (P b) = compare a b

sh :: O -> String
sh (O a c) = show a ++ [c]

data V = V1 | V2 Int deriving (Eq, Ord)

main :: IO ()
main = do
  print (compare (O 1 'x') (O 2 'y'), compare (O 2 'x') (O 2 'y'), compare (O 3 'x') (O 2 'y'))
  print (O 1 'a' < O 2 'b', O 2 'a' > O 1 'b', O 1 'a' >= O 1 'b')
  print (P 1 < P 2, P 1 <= P 1, P 2 > P 1, P 1 >= P 2)
  putStrLn (sh (max (O 1 'a') (O 1 'b')) ++ " " ++ sh (min (O 1 'a') (O 1 'b')))
  print (max (P 1) (P 2) == P 2, min (P 1) (P 2) == P 1)
  print [compare 1 (2 :: Int), compare 2 (1 :: Integer), compare 1.5 (1.5 :: Double), compare 'b' 'a', compare False True, compare [1] [1, 2 :: Int], compare (1 :: Int, 'b') (1, 'a'), compare LT GT]
  print (V1 < V2 0, compare (V2 2) (V2 1), max V1 (V2 5) == V2 5)
