-- A method added: the class moves with its methods, and its instance, which mentions it; a value stays.
module All (C(..), v) where

class C a where
  m :: a -> Int
  m2 :: a -> Bool
  m2 _ = True

instance C Bool where
  m _ = 1

v :: Int
v = 0
