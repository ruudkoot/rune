-- rows: syn.pat.2 syn.pati.1 syn.pati.2 syn.pati.3 syn.lpati.1 syn.lpat6.1 syn.rpati.1 syn.pat10.1 syn.pat10.2 syn.apat.1 syn.apat.2 syn.apat.3 syn.apat.4 syn.apat.5 syn.apat.6 syn.apat.7 syn.apat.8 syn.apat.9 syn.fpat.1 syn.gcon.1 syn.gcon.2 syn.gcon.3 syn.gcon.4 syn.var.1 syn.qvar.1 syn.con.1 syn.qcon.1 syn.varop.1 syn.qvarop.1 syn.conop.1 syn.qconop.1 syn.op.1 syn.qop.1 syn.gconsym.1 syn.funlhs.1 syn.funlhs.2 syn.funlhs.5 syn.r.funlhs.oneapat syn.r.funlhs.paren syn.r.decl.pat0 syn.r.pat.nplusk.top syn.r.pat.neg syn.r.pat.notnested.neg syn.r.qcon.gconsym syn.r.qconop.colon
-- Report 9.5: pat and the patterns it holds in each form, n+k at its top, negative literals, constructors and
-- operators in their forms, and funlhs in each of its five forms.
module Main (main) where

import qualified Complex as Cx

infixl 5 :<
infixr 5 :>
infix 4 =.=

data L = Nil | L :< Int
data R = End | Int :> R
data T = C Int Int | D { da :: Int, db :: Int } | E | Int `F` Int

f :: L -> Int
f (Nil :< a :< b) = a + b
f _ = 0

g :: R -> Int
g (a :> b :> End) = a + b
g _ = 0

h :: T -> Int
h (C 1 n) = n
h (C (-1) _) = -1
h D { da = x, db = _ } = x
h D {} = 0
h t@E = case t of E -> 2
h (a `F` b) = a + b

k :: Int -> Int
k (n+1) = case n of m+1 -> m ; _ -> n
k _ = 0

m :: (Int, [Int], Maybe Int, ()) -> Int
m (x, [y, z], ~(Just w), ()) = x + y + z + w
m (_, [], _, _) = 0
m _ = 1

p :: [Int] -> Int
p ((:) x _) = x
p [] = 0

q :: Cx.Complex Double -> (Int, Int) -> Double
q ((Cx.:+) re _) ((,) _ _) = re

(=.=) :: Int -> Int -> Bool
x =.= y = x == y

(f2 x) y = x + y :: Int
(x `g2` y) z = x + y + z :: Int

main :: IO ()
main = do
  print (f (Nil :< 1 :< 2), g (1 :> 2 :> End), h (1 `Main.F` 2), k 3, m (1, [2, 3], Just 4, ()))
  print (p [1], q (1 Cx.:+ 2) (3, 4), 1 =.= 1, f2 1 2, g2 1 2 3)
  print (let { a + 1 = a } in 5 + 1 :: Int, let { y -1 = y } in 5 - 1 :: Int, 1 `Prelude.div` 1)
  print ((Main.:<) Nil 1 `seq` (), 1 : [], (Prelude.+) 1 2)
