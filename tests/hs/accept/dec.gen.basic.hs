-- rows: dec.gen.nested.ctx dec.gen.group.ctx dec.gen.sig.renamed
-- Report 4.5.2: a let's variables are quantified unless the environment holds them; a local function may be overloaded;
-- a group's constraints form each variable's context, as in the Report's g1 and g2; signed contexts identical up
-- to renaming.
module Main (main) where

f x = let g y = (y, y) in (g 1, g 'c')

d = let dd x = x + x in (dd 1, dd 1.5)

g1 x y = if x > y then show x else g2 y x
g2 p q = g1 q p

e1 :: Eq a => a -> Bool
e1 x = e2 x
e2 :: Eq b => b -> Bool
e2 y = y == y || e1 y

main :: IO ()
main = print (f (), d, g1 1 2, g2 'a' 'b', e1 True)
