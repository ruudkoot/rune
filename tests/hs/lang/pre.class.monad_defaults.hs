-- rows: pre.class.monad pre.class.monad.gtgteq pre.class.monad.gtgt pre.class.monad.return pre.class.monad.fail
-- Report 8: class Monad's defaults: m >> k = m >>= \_ -> k and fail s = error s; >>= and return have none; every method
-- defined overrides its default.
module Main (main) where

newtype W a = W (a, String)
instance Monad W where
  return a = W (a, "r")
  W (a, s) >>= f = let W (b, t) = f a in W (b, s ++ "b" ++ t)

newtype V a = V (Maybe a)
instance Monad V where
  return = V . Just
  V Nothing >>= _ = V Nothing
  V (Just a) >>= f = f a
  _ >> _ = V Nothing
  fail _ = V Nothing

logOf :: W a -> String
logOf (W (_, s)) = s

un :: V a -> Maybe a
un (V m) = m

main :: IO ()
main = do
  putStrLn (logOf (W ((), "x") >> W ((), "y")))
  putStrLn (logOf (return () :: W ()))
  print (un (return (1 :: Int) >> return (2 :: Int)), un (do { Just x <- return Nothing; return (x :: Int) }))
