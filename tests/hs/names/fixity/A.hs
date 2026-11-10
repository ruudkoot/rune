-- An operator +++, non-associative at precedence 4, as == is; <+> right at
-- 5, as ++ is; a constructor :& left at 6, tighter than :.
module A ((+++), (<+>), Pair(..)) where

infix 4 +++
infixr 5 <+>
infixl 6 :&

data Pair = Int :& Int

(+++) :: Int -> Int -> Bool
a +++ b = a == b

(<+>) :: [a] -> [a] -> [a]
xs <+> ys = xs ++ ys
