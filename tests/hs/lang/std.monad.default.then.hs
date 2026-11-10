-- rows: std.monad.fail.do
-- Report 6.3.6: >> defaults to m >>= \_ -> k; a user fail is what a failed match in do calls.
module Main (main) where

newtype M a = M (Maybe a)

instance Monad M where
  return = M . Just
  M Nothing >>= _ = M Nothing
  M (Just a) >>= f = f a
  fail _ = M (Just (error "marker"))

un :: M a -> Maybe a
un (M m) = m

isJ :: Maybe a -> Bool
isJ (Just _) = True
isJ Nothing = False

main :: IO ()
main = do
  print (un (return (1 :: Int) >> return (2 :: Int)))
  print (un (M Nothing >> return (2 :: Int)))
  print (isJ (un (do { Just x <- return Nothing; return (x :: Int) })))
