-- rows: cls.inst.ctx.qualifiedclass cls.inst.body.anyname cls.inst.body.funforms cls.inst.missing.compile cls.inst.kind.partial cls.inst.super.valid cls.inst.ctx.more
-- Report 4.3.2: instances; a qualified class in the head and a method bound by its unqualified name though only the qualified
-- one is in scope; bindings of any function form; a method with neither binding nor default; a type constructor
-- applied to fewer variables; the Report's valid pair of contexts; a context stronger than needed.
module Main (main) where

import qualified Ix

data T = T0 | T1 deriving (Eq, Ord, Show)

instance Ix.Ix T where
  range (a, b) = [a .. b]
  index (a, _) i = fromEnum i - fromEnum a
  inRange (a, b) i = a <= i && i <= b

instance Enum T where
  fromEnum T0 = 0
  fromEnum T1 = 1
  toEnum 0 = T0
  toEnum _ = T1

data U = U
instance Eq U where
  x == y = True
data V = V
instance Eq V where
  (==) x y = True
data X = X
instance Eq X where
  (==) = \_ _ -> True

class C a where
  m :: a -> Int
  n :: a -> Int
instance C Bool where
  m _ = 1

data Pair a b = Pair a b
class Fun f where
  fun :: (a -> b) -> f a -> f b
instance Fun (Pair a) where
  fun g (Pair a b) = Pair a (g b)

class (Eq a, Show a) => Foo a where
  foo :: a -> String
  foo = show
class Foo a => Bar a
instance (Eq a, Show a) => Foo [a]
instance Num a => Bar [a]

class D a where
  dd :: a -> Int
  dd _ = 0
instance Show a => D [a]

main :: IO ()
main = do
  print (Ix.range (T0, T1), U == U, V == V, X == X)
  print (m True, dd [1])
