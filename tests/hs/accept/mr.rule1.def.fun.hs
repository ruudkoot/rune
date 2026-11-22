-- rows: mr.rule1.def.simple.sig mr.rule1.unconstrained mr.ex.len.sig mr.ex.reads mr.ex.nonsimple.monosig mr.ex.nonsimple.unconstrained.sig mr.rule2.nested mr.conseq.fun mr.conseq.lambda.sig mr.conseq.sum mr.noext
-- Report 4.5.5: function bindings and signed simple pattern bindings are unrestricted, unconstrained variables are
-- generalised, a signature restores len's overloading, [(n,s)] = reads t is monomorphic and fixed by its use, a
-- non-simple binding takes a monomorphic or unconstrained signature, nested bindings see their whole scope.
-- genericLength is 4.5.5's, at Num a => [b] -> a: List's is Integral a => [b] -> a (R48), at which len :: Double
-- does not type.
module Main (main) where

genericLength :: Num a => [b] -> a
genericLength = foldr (\_ n -> n + 1) 0

f x y = x + y

g :: Num a => a -> a
g = \x -> x

sumAll :: Num a => [a] -> a
sumAll = foldl (+) 0

ff :: Num a => a -> a -> a
ff = \x -> \y -> x + y

(p, q) = ((+), (-))
p :: Int -> Int -> Int

(i, j) = (id, id)
i :: a -> a

main :: IO ()
main = do
  print (f (1 :: Int) 2, f 1.5 2, g (1 :: Int), g 1.5)
  print (sumAll [1 :: Int], sumAll [1.5])
  print (let x = [] in (1 : x, 'c' : x), let { len :: Num a => a ; len = genericLength "ab" } in (len :: Int, len :: Double))
  print (let [(n, s)] = reads "1 x" in (n + 1 :: Int, s), let z = 1 in z :: Double, ff 1 (2 :: Int), ff 1.5 2)
  print (p 1 2, i 'c', i True)
