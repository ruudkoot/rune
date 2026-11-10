-- rows: dec.dep.order dec.dep.order.polymorphism dec.dep.split dec.dep.top
-- Report 4.5.1: Hindley-Milner after dependency analysis, which ignores the written order: a use before its definition,
-- at the top, in a let and in a where, stays polymorphic.
module Main (main) where

a :: (Int, Char)
a = (f 1, f 'c')

f x = x

main :: IO ()
main = print (a, let { g = (h 1, h 'c') ; h y = y } in g, k)
  where
    k = (j True, j 'c')
    j z = z
