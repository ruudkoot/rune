-- rows: ty.ctx.app ty.ctx.qualified ty.sem.valid.one ty.sem.valid.two ty.sem.valid.three ty.sem.preorder.subst ty.sem.instantiate ty.sem.instantiate.user
-- Report 4.1.3: an assertion is qtycls tyvar or a class applied to a variable applied to types, the class qualified or
-- not; 4.1.4: the Report's three valid types, a binding used through a less general signature, and
-- instantiation where the context holds, here by a user's instance Num Char.
module Main (main) where

f :: Eq a => a -> a -> Bool
f = (==)

g :: Eq (m a) => m a -> Bool
g x = x == x

g2 :: Eq (m a [b]) => m a [b] -> Bool
g2 x = x == x

h :: Prelude.Eq a => a -> Bool
h x = x == x

v1 :: Eq a => a -> a
v1 x = x

v2 :: (Eq a, Show a, Eq b) => [a] -> [b] -> String
v2 xs ys = if xs == xs && ys == ys then show xs else ""

v3 :: (Eq (f a), Functor f) => (a -> b) -> f a -> f b -> Bool
v3 _ xs _ = xs == xs

general :: a -> a
general x = x

lessGeneral :: Int -> Int
lessGeneral = general

double :: Num a => a -> a
double x = x + x

instance Num Char where
  a + b = toEnum (fromEnum a + fromEnum b)
  a * b = toEnum (fromEnum a * fromEnum b)
  abs = id
  signum = id
  negate = id
  fromInteger = toEnum . fromInteger

main :: IO ()
main = do
  print (f 1 1, g (Just 1), g2 (Left 1 :: Either Int [Bool]), h 'c', v1 1)
  print (v2 [1] [True], v3 id (Just 1) (Just 2), lessGeneral 1, double (1 :: Int), double 'a')
