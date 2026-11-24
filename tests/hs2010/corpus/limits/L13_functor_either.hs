-- Report: Either e is no Functor or Monad in the Prelude; a program may define those instances.
module Main where
instance Functor (Either e) where
  fmap _ (Left e) = Left e
  fmap f (Right a) = Right (f a)
main = print (fmap (+ 1) (Right 2 :: Either String Int))
