-- Report 4.3.2: the class and the type have one kind: not Functor Int.
module Main (main) where

instance Functor Int where
  fmap = undefined

main :: IO ()
main = return ()
