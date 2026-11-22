-- rows: std.either.data std.ordering.data std.ordering.compare std.maybe.functor std.maybe.monad std.maybe.fns
-- Report 6.1.8: Maybe, Either and Ordering, their classes in the order declared; fmap and do at Maybe; maybe and either.
module Main (main) where

main :: IO ()
main = do
  print (Nothing < Just (1 :: Int), Just 1 == Just (1 :: Int), read "Just 2" :: Maybe Int, show (Just 'a'))
  print (Left 5 < (Right 1 :: Either Int Int), Left 1 == (Left 1 :: Either Int Int), read "Right 3" :: Either Int Int, show (Left 'a' :: Either Char Int))
  print ([LT ..], LT < EQ, EQ < GT, read "GT" :: Ordering, show EQ)
  print (minBound :: Ordering, maxBound :: Ordering, succ LT, fromEnum GT)
  print (compare 1 (2 :: Int), compare 2 (2 :: Int), compare 3 (2 :: Int))
  print (fmap (+ 1) (Just (1 :: Int)), fmap (+ 1) (Nothing :: Maybe Int), do { x <- Just 1; y <- Just 2; return (x + y :: Int) })
  print (maybe 0 (+ 1) (Just (5 :: Int)), maybe 0 (+ 1) (Nothing :: Maybe Int), either length negate (Left "ab" :: Either String Int), either length negate (Right 3 :: Either String Int))
