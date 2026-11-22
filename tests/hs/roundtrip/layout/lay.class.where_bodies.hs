module M where
class C a where
  m :: a -> a
  m = id
class D a
instance C Int where
  m x = x
