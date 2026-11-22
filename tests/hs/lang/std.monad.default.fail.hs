-- Report 6.3.6: fail defaults to error: a user instance's failed do pattern ends the program.
module Main (main) where

newtype M a = M (Maybe a)

instance Monad M where
  return = M . Just
  M Nothing >>= _ = M Nothing
  M (Just a) >>= f = f a

un :: M a -> Maybe a
un (M m) = m

main :: IO ()
main = print (un (do { Just x <- return Nothing; return (x :: Int) }))
