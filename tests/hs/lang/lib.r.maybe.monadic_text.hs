-- Report 18: other operations on Maybe are the Prelude's monadic classes: fmap, >>=, return, >> and do on Maybe with no
-- import of the library.
module Main (main) where

half :: Int -> Maybe Int
half n = if even n then Just (n `div` 2) else Nothing

main :: IO ()
main = do
  print (fmap (+ 1) (Just (1 :: Int)), fmap (+ 1) (Nothing :: Maybe Int), Just (8 :: Int) >>= half >>= half, Just (6 :: Int) >>= half >>= half)
  print (return 'x' :: Maybe Char, (Nothing :: Maybe Int) >> Just True, Just (1 :: Int) >> Just True, sequence [Just 1, Just (2 :: Int)], sequence [Just 1, Nothing :: Maybe Int])
  print (do { a <- Just (3 :: Int); b <- half 4; return (a + b) }, mapM half [2, 4, 6], mapM half [2, 3], maybe 0 (+ 1) (Just (5 :: Int)))
