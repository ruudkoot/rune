-- rows: kind.infer.unify kind.infer.class kind.default.star kind.default.tree kind.default.dep.mutual
-- Report 4.6: kinds by dependency group, the Report's D, S and C; a class variable's kind from its methods; open parts
-- default to *; a later declaration of the same group constrains a kind.
module Main (main) where

data C a => D a = Foo (S a)
type S a = [D a]
class C a where
  bar :: a -> D a -> Bool

class F f where
  m :: f a -> a
instance F Maybe where
  m (Just x) = x

data App f a = A (f a)
data Tree a = Leaf | Fork (Tree a) (Tree a)
data T a = TC (U a)
data U f = UD (f Int)

app :: App Maybe Int
app = A (Just 1)

tree :: Tree Int
tree = Leaf

t :: T Maybe
t = TC (UD (Just 1))

main :: IO ()
main = return ()
