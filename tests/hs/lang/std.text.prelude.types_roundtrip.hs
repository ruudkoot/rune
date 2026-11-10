-- rows: R47
-- Report 6.3.3 (readings.md R47): every Prelude type but functions, IO and IOError is in Show and Read: read of show is
-- the value, at each.
module Main (main) where

rt :: (Read a, Show a, Eq a) => a -> Bool
rt x = read (show x) == x

main :: IO ()
main = do
  print [rt (3 :: Int), rt (-7 :: Integer), rt (2.5 :: Float), rt (0.125 :: Double), rt 'q', rt True, rt ()]
  print [rt LT, rt (Just (1 :: Int)), rt (Left 'a' :: Either Char Int), rt [1, 2 :: Int], rt (1 :: Int, 'b'), rt "s\n", rt (3 :: Rational)]
