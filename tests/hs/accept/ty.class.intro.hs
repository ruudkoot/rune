-- rows: ty.class.constructor kind.star kind.arrow ty.form.var ty.form.con ty.form.app ty.form.app.partial ty.form.paren ty.kind.maybe ty.kind.user ty.unit ty.fun.prefix ty.list.prefix ty.tuple.prefix ty.fun.sugar ty.fun.rightassoc ty.tuple.sugar ty.list.sugar ty.consistent ty.quant.implicit ty.quant.classvar
-- Report 4.1, 4.1.1, 4.1.2: a class and its overloaded operations, instances at two types, a constructor class, a class
-- over a variable of kind (*->*)->*, type variables whose kinds their context fixes, the built-in constructors
-- in their special and prefix forms, implicit quantification, and the class variable at one type in an instance.
module Main (main) where

class MyNum a where
  plus :: a -> a -> a
  zero :: a

data N = Z | S N deriving Show
data P = P Int deriving Show

instance MyNum N where
  plus Z n = n
  plus (S m) n = S (plus m n)
  zero = Z

instance MyNum P where
  plus (P a) (P b) = P (a + b)
  zero = P 0

class Box f where
  unbox :: f a -> a

instance Box Maybe where
  unbox (Just x) = x
  unbox Nothing = error "empty"

class Hk t where
  hk :: t Maybe -> Int

data W f = W (f Int)

instance Hk W where
  hk (W _) = 0

ident :: m a -> m a
ident x = x

sigs :: (Char, Int, Integer, Float, Double, Bool) -> (Maybe Int, IO (), Either Int Bool, (Either Int) Bool, ((Int) -> (Int)))
sigs _ = (Nothing, return (), Left 1, Right True, id)

unit :: ()
unit = ()

f1 :: (->) Int Int
f1 = id

xs :: [] Int
xs = [1]

p :: (,) Int Bool
p = (1, True)

q :: (,,) Int Bool Char
q = (1, True, 'c')

g1 :: Int -> Int -> Float
g1 a b = fromIntegral (a + b)

g2 :: Int -> (Int -> Float)
g2 = g1

tup :: (Int, Bool)
tup = p

lst :: [Int]
lst = xs

fun :: Int -> Int
fun = f1

cons :: a -> b -> (a -> b, [a], (a, b))
cons e1 e2 = (\_ -> e2, [e1], (e1, e2))

twice :: a -> a
twice x = x

main :: IO ()
main = do
  print (plus (S Z) zero, plus (P 1) zero, unbox (Just 'c'), hk (W Nothing))
  print (twice (1 :: Int), twice 'c', g2 1 2, ident (Just 1), unit)
  print (fun 1, lst, tup, q)
