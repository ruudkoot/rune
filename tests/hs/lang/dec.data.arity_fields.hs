-- rows: dec.field.positional dec.field.order dec.field.pattern.empty ty.builtin.semantics
-- Report 4.2.1, 4.1.2: a constructor of arity k matches k components; a record constructor is positional too, its fields in
-- their order; K {} matches any K and no other constructor; the built-in list and pair match as declared ones do.
module Main (main) where

data C = F { f1, f2 :: Int, f3 :: Bool }
data T = G Int Int | H
data L a = Nil | Cons a (L a)
data P a b = P a b

f :: C -> Int
f (F a b c) = if c then a + b else 0

g :: T -> String
g (G {}) = "G"
g _ = "other"

main :: IO ()
main = do
  print (f (F 1 2 True), f1 (F 1 2 True), case F 1 2 False of F a b c -> (a, b, c))
  print (g (G undefined undefined), g H)
  print (case [undefined, undefined :: Int] of { (_ : _) -> "cons"; [] -> "nil" }, case Cons (undefined :: Int) Nil of { Cons _ _ -> "cons"; Nil -> "nil" })
  print (case (undefined :: Int, 1 :: Int) of (_, y) -> y, case P (undefined :: Int) (1 :: Int) of P _ y -> y)
