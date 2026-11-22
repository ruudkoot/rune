-- rows: cls.class.super cls.class.super.dag cls.method.bysig cls.method.scope cls.method.type cls.method.othervars cls.method.ctx.w cls.default.var cls.default.fun cls.default.guards cls.class.emptyinstance cls.class.higher
-- Report 4.3.1: a class and its methods, superclasses (a diamond), methods named by their signatures and scoped at the top,
-- a method's type (C u, cx) => t with other variables constrained, defaults of each form, an instance with no
-- where, and a class over a higher kind.
module Main (main) where

class Base a where
  base :: a -> Int
class Base a => Left2 a where
  left2 :: a -> Int
class Base a => Right2 a where
  right2 :: a -> Int
class (Left2 a, Right2 a) => Diamond a where
  diamond :: a -> Int
  diamond x = left2 x + right2 x + base x

class Foo a where
  op, op2 :: Num b => a -> b -> a
  op x _ = x
  op2 = \x _ -> x
  (<+>) :: a -> a -> a
  a <+> _ = a
  pick :: a -> Bool -> a
  pick x b | b = x
           | otherwise = y
    where y = x

class (Read a, Show a) => Textual a

class Fun f where
  fun :: (a -> b) -> f a -> f b

instance Base Int where base = id
instance Left2 Int where left2 = (* 2)
instance Right2 Int where right2 = (* 3)
instance Diamond Int
instance Foo Int
instance Textual Int
instance Fun Maybe where
  fun f = maybe Nothing (Just . f)

opAt :: (Foo a, Num b) => a -> b -> a
opAt = op

viaSuper :: Diamond a => a -> Int
viaSuper x = base x

main :: IO ()
main = do
  print (diamond (1 :: Int), op (1 :: Int) (2 :: Integer), op (1 :: Int) (2.5 :: Double), opAt (1 :: Int) (1 :: Int))
  print ((1 :: Int) <+> 2, pick (1 :: Int) False, viaSuper (2 :: Int), fun (+ 1) (Just 1))
