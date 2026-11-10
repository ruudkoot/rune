-- rows: syn.funlhs.4
-- Report 9.5: funlhs -> lpat(i) varop(l,i) pat(i+1) | pat(i+1) varop(r,i) rpat(i): an infix definition whose left
-- argument, of a left-associative operator, is a pattern of a left-associative constructor at its level, and the
-- same on the right.
module Main (main) where

infixl 5 :<, +<
infixr 5 :>, >+

data L = Nil | L :< Int
data R = End | Int :> R

(+<) :: L -> Int -> Int
l :< x +< y = x + y
_ +< y = y

(>+) :: Int -> R -> Int
x >+ y :> _ = x + y
_ >+ End = 0

main :: IO ()
main = print ((Nil :< 1) +< 2, 1 >+ (2 :> End))
