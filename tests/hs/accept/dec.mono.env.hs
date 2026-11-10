-- rows: dec.mono.b.poly dec.mono.sig.concrete
-- Report 4.5.4: a variable of the environment leaves g monomorphic in it, forcing x to Bool, while b stays polymorphic; a
-- signature may name x's type where it has no variable.
module Main (main) where

f x = let g y z = ([x, y], z) in (g True 1, g False 'c')

h :: Int -> ([Int], Bool)
h x = let { g :: Int -> b -> ([Int], b) ; g y z = ([x, y], z) } in g 1 True

main :: IO ()
main = print (f True, h 1)
