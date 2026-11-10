-- rows: dec.type.kind dec.type.higher dec.type.rec.throughdata dec.type.interchange
-- Report 4.2.2: a synonym is its expansion; its kind is inferred, may be higher, recursion through a datatype is allowed,
-- and String and [Char] are interchangeable.
module Main (main) where

type Pair a = (a, a)
type T f a = f a
type List = []
type Rec a = [Circ a]
data Circ a = Tag [Rec a]

p :: Pair Int
p = (1, 2)

q :: (Int, Int)
q = p

t :: T Maybe Int
t = Just 1

xs :: List Int
xs = [1]

r :: Rec Int
r = [Tag []]

f :: String -> [Char]
f x = x

main :: IO ()
main = print (q, t, xs, length r, f "s")
