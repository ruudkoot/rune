-- HsLint's second inference: kinds inferred and defaulted to * (Report 4.6), derived instances with
-- their least contexts (4.3.3, 10.1), a synonym expanded, a constructor class and its method used
-- at an instance.
module Main (main) where

data T a = C [a] (Maybe a) deriving (Eq, Show)
data App f a = App (f a)
newtype N = N Int deriving (Eq, Ord)
data E = A | B | D deriving (Eq, Ord, Enum, Bounded, Show, Read)
data Rose a = Rose a [Rose a] deriving (Eq, Show)
type Pair a = (a, a)

class Container f where
  empty :: f a
  insert :: a -> f a -> f a

instance Container [] where
  empty = []
  insert = (:)

swap :: Pair a -> Pair a
swap (x, y) = (y, x)

single x = insert x empty

main :: IO ()
main = print (C [1] Nothing == C [] (Just 2), swap (1, 2), single 'c' :: [Char], [minBound .. maxBound :: E])
