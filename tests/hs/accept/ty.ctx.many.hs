-- rows: ty.ctx.empty ty.ctx.parens
-- Report 4.1.3: context -> class | ( class1 , ... , classn ), n >= 0: several assertions, none, and one with or
-- without its parentheses.
module Main (main) where

f :: (Eq a, Show a) => a -> String
f = show

g :: () => Int
g = 1

h :: Eq a => a -> Bool
h x = x == x

k :: (Eq a) => a -> Bool
k x = x == x

main :: IO ()
main = print (f g, h g, k g)
