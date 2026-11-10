-- rows: lib.monad.class.monadplus.mplus lib.monad.class.monadplus lib.r.monad.monadplus.class
-- Report 20.2, 20.4: class Monad m => MonadPlus m with mzero and mplus and no defaults: a user instance (its mplus
-- reversed) compiles, and guard, msum and the methods use its own. The expected output is worked by hand.
module Main (main) where

import Monad

newtype P a = P [a]

unP :: P a -> [a]
unP (P xs) = xs

instance Monad P where
  return x = P [x]
  P xs >>= f = P (concat (map (unP . f) xs))

instance MonadPlus P where
  mzero = P []
  P a `mplus` P b = P (b ++ a)

pos :: (MonadPlus m) => Int -> m Int
pos x = if x > 0 then return x else mzero

main :: IO ()
main = do
  print (unP (msum [P [1, 2], P [3], P [4 :: Int]]), unP (mplus (P "ab") (P "cd")), unP (mzero :: P Char))
  print (unP (pos 3 `mplus` pos 0 `mplus` pos 5), unP (do { x <- P [1, 2, 3 :: Int]; guard (odd x); return (x * 10) }))
  print (pos 2 :: Maybe Int, pos 0 :: [Int])
