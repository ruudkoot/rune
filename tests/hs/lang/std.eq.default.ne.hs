-- rows: std.eq.default.eq std.eq.both std.eq.basic std.eq.derive std.class.minimal
-- Report 6.3.1: Eq's defaults: an instance with == alone or /= alone has both; one with both keeps its own, the
-- negation or not; the Prelude's types and a derived instance.
module Main (main) where

data A = A1 | A2

instance Eq A where
  A1 == A1 = True
  A2 == A2 = True
  _ == _ = False

data B = B1 | B2

instance Eq B where
  B1 /= B2 = True
  B2 /= B1 = True
  _ /= _ = False

data W = W Int

instance Eq W where
  W a == W b = a == b
  _ /= _ = True

data V = V1 | V2 Int deriving (Eq, Ord)

main :: IO ()
main = do
  print (A1 /= A2, A1 /= A1, B1 == B1, B1 == B2)
  print (W 1 == W 1, W 1 /= W 1)
  print (V1 == V1, V2 1 == V2 2, V1 < V2 0, V2 1 < V2 2, compare (V2 3) (V2 3))
  print [1 == (1 :: Int), 1 == (1 :: Integer), 1.5 == (1.5 :: Float), 1.5 == (1.5 :: Double), 'a' == 'a', True == True, () == (), [1] == [1 :: Int], (1 :: Int, 'a') == (1, 'a'), LT == LT, (Left 1 :: Either Int Int) == Left 1, (1 :: Rational) == 1]
