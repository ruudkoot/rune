module Decls where

-- Algebraic data types: contexts, strict fields, infix and record
-- constructors, every form of deriving.
data Maybe' a = Nothing' | Just' a deriving (Eq, Ord, Show)
data (Eq a) => Set a = NilSet | ConsSet a (Set a) deriving Eq
data Pair a b = Pair !a !b
data Complex = !Double :+ !Double deriving (Eq, Read)
data Tree a = Leaf | Node (Tree a) a (Tree a) deriving ()
data Op = Int `Plus` Int | Int :* Int | (:-:) Int Int
data Rec a = Rec { name :: String, size, weight :: !Int, items :: [a] }
           | Empty {}
data Fun = Fun (Int -> Int) [Maybe Int] (Int, Bool) () [] (->) (,) (,,)

newtype Age = Age Int deriving (Show)
newtype Wrapped a = Wrap { unwrap :: a }
newtype (Ord a) => Sorted a = Sorted [a]

type Name = String
type Assoc k v = [(k, v)]
type Endo a = a -> a
type F = (->) Int

-- Classes: superclasses, signatures with contexts, fixity, defaults.
class Container f where
  empty :: f a
  insert :: a -> f a -> f a
  toList :: f a -> [a]
  infixr 5 `insert`

class (Eq a, Show a) => Pretty a where
  pretty :: a -> String
  pretty = show
  prettyList :: [a] -> String
  prettyList xs = concatMap pretty xs

class Monad' m where
  return' :: a -> m a
  (>>>=) :: m a -> (a -> m b) -> m b

-- Instances: every form of the Report's inst.
instance Container [] where
  empty = []
  insert = (:)
  toList xs = xs

instance Pretty Int
instance (Pretty a) => Pretty [a] where
  pretty xs = "[" ++ concatMap pretty xs ++ "]"
instance (Pretty a, Pretty b) => Pretty (a, b) where
  pretty (a, b) = pretty a ++ pretty b
instance Pretty ()
instance Monad' ((->) r) where
  return' = const
  f >>>= k = \r -> k (f r) r
instance Eq (a -> b) where
  _ == _ = False
instance (Show a) => Show (Tree a)

default (Integer, Double)
default ()

-- Fixity declarations, with and without a precedence.
infixl 6 <+>, `plus`
infix 4 ===
infixr 0 $$
infixl :::

(<+>), plus, (===), ($$) :: Int -> Int -> Int
a <+> b = a + b
plus = (+)
a === b = a
f $$ x = f + x

data L = Int ::: Int

-- Signatures with contexts.
sizeOf :: (Container f, Show a) => f a -> Int
sizeOf = length . toList
pairUp :: Eq a => a -> a -> Bool
pairUp = (==)
