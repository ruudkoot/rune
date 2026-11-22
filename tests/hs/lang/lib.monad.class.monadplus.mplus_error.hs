-- Report 20.4: MonadPlus has no default for mplus: an instance without one compiles, and its mplus is bottom.
module Main (main) where

import Monad

newtype Q a = Q (Maybe a)

instance Monad Q where
  return x = Q (Just x)
  Q Nothing >>= _ = Q Nothing
  Q (Just x) >>= f = f x

instance MonadPlus Q where
  mzero = Q Nothing

unQ :: Q a -> Maybe a
unQ (Q m) = m

main :: IO ()
main = do
  print (unQ (mzero :: Q Int))
  print (unQ (mplus (return 1) (return (2 :: Int))))
