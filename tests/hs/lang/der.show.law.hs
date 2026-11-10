-- rows: der.read.roundtrip der.show.syntactic der.show.nolinebreak der.read.infix.prec der.tree.read.terminates
-- Report 10.4: showsPrec d x r ++ s is showsPrec d x (r ++ s); readsPrec d (showsPrec d x "") gives x back at every d from
-- 0 to 10; no newline of its own; an infix constructor reads at d = p and not at p + 1 without parentheses; a deep
-- tree reads back.
module Main (main) where

infixr 5 :^:
data Tree a = Leaf a | Tree a :^: Tree a deriving (Eq, Show, Read)

data T = A | B Int | Int :+ Int deriving (Eq, Show, Read)
infixl 6 :+

xs :: [T]
xs = [A, B 1, B (-2), 1 :+ 2, (-1) :+ 3]

deep :: Tree Int
deep = foldr (\n t -> Leaf n :^: t) (Leaf 0) [1 .. 50]

main :: IO ()
main = do
  print (and [showsPrec d x "r" ++ "s" == showsPrec d x "rs" | d <- [0 .. 11], x <- xs])
  print (and [[(x, "")] == readsPrec d (showsPrec d x "") | d <- [0 .. 10], x <- xs])
  print (notElem '\n' (show deep), read (show deep) == deep)
  print (length (readsPrec 6 "1 :+ 2" :: [(T, String)]), length (readsPrec 7 "1 :+ 2" :: [(T, String)]), length (readsPrec 7 "(1 :+ 2)" :: [(T, String)]))
