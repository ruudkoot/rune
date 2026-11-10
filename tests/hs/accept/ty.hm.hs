-- rows: ty.sem.principal
-- Report 4.1: "The Haskell type system ... is Hindley-Milner polymorphism extended with type classes"; 4.1.4: the principal
-- type of every expression is inferred, so signatures are optional: a let-polymorphic, overloaded program with none.
module Main (main) where

main = print (pair 1 'c', double 2, double 2.5, compose not not True)
  where
    pair x y = (x, y)
    double x = x + x
    compose f g x = f (g x)
