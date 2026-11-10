-- rows: std.text.derived.style der.read.methods der.show.result der.show.paren.zero der.show.paren.eleven der.show.paren.atomic der.show.app.prec der.show.arg.prec der.show.neg.integer der.show.only der.show.parens.needed der.show.showlist der.show.infix.args der.show.infix.spaces der.show.example.fixity der.show.fixity.declared der.show.fixity.default der.show.assoc.ignored der.show.prec.range der.show.paren.rule der.read.result der.read.empty der.read.parens der.read.string.quoted der.read.list.bracket der.read.infix.only der.read.assoc.paren der.read.record.only der.read.record.order der.tree.show.leaf der.tree.show.node der.tree.show.assoc der.tree.eq der.tree.read.leaf der.tree.read.node
-- Report 10.4: derived showsPrec parenthesises an application above 10 and an infix one above its precedence, shows
-- negative numbers by showSigned and ignores associativity; derived readsPrec reads what show writes, in
-- parentheses or not; the Report's Tree with :^: infixr 5.
module Main (main) where

infixr 5 :^:
data Tree a = Leaf a | Tree a :^: Tree a deriving (Eq, Ord, Show, Read)

data T = A | B Int | Int :+ Int deriving (Show, Read, Eq)
infixl 6 :+
data U = U Int Int deriving (Show, Read)
infixr 9 :$
data E = NT | Int :$ E deriving (Show, Read)
data R = C {f :: Int, g :: Int} deriving (Show, Read)

main :: IO ()
main = do
  putStrLn (showsPrec 0 A "x")
  print (showsPrec 10 (B 1) "", showsPrec 11 (B 1) "", showsPrec 11 A "", showsPrec 11 (Just (1 :: Int)) "")
  print (showsPrec 6 (1 :+ 2) "", showsPrec 7 (1 :+ 2) "", show (Just (Just (1 :: Int))), show (Just (-1 :: Int)))
  print (show [A, B 2], show (Leaf (1 :: Int) :^: Leaf 2 :^: Leaf 3), showsPrec 5 (Leaf (1 :: Int) :^: Leaf 2) "", showsPrec 6 (Leaf (1 :: Int) :^: Leaf 2) "")
  print (showsPrec 10 (Leaf (1 :: Int)) "", showsPrec 11 (Leaf (1 :: Int)) "", show (1 :$ 2 :$ NT))
  print (reads "A rest" :: [(T, String)], reads "?" :: [(T, String)], read "((A))" :: T, read " ( 1 :+ 2 ) " :: T)
  print (reads "['a']" :: [(String, String)], reads "1:[]" :: [([Int], String)], reads "(:$) 1 NT" :: [(E, String)])
  print (read "1 :$ (2 :$ NT)" :: E, reads "C 1 2" :: [(R, String)], reads "C {g = 2, f = 1}" :: [(R, String)])
  print (Leaf 1 :^: Leaf 2 == Leaf (1 :: Int) :^: Leaf 2, read "Leaf 3" :: Tree Int, read "Leaf 1 :^: (Leaf 2 :^: Leaf 3)" :: Tree Int)
