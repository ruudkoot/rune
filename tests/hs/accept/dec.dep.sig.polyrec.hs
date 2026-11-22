-- rows: dec.dep.sig.group R21
-- Report 4.5.1 and 4.4.1: a signed binding's uses in its group are at its declared type, so a signature cuts the group for
-- typing (R21(c): rhc splits explicit from implicit bindings, as Typing Haskell in Haskell does, D32).
module Main (main) where

f :: a -> a
f x = const x (g 1)

g y = const y (f 'c', f True)

main :: IO ()
main = print (f True, g (2 :: Int))
