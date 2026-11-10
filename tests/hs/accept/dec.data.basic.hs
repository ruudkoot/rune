-- rows: dec.data.contype dec.data.cxi dec.data.ctx.inferred dec.data.ctx.noother dec.data.ctx.unusedvar dec.data.kind dec.data.partial dec.field.syntax dec.field.mixed dec.field.shared.same dec.field.shared.synonym
-- Report 4.2.1: data declarations and their constructors' types, the Report's Set with its context (whose constructor
-- NilSet has none), a context with no other effect, kinds by inference, partial application of a type
-- constructor, field labels shared with the same type (after synonyms), and labelled and plain constructors mixed.
module Main (main) where

data Eq a => Set a = NilSet | ConsSet a (Set a)
data T0 = A0 | B0 Int | C0 Bool Char deriving Show
data Eq a => U a = UA | UB a
data T1 f a = T1 (f a)
data Either2 a b = L2 a | R2 b

class Fun f where
  fmap2 :: (a -> b) -> f a -> f b

instance Fun (Either2 a) where
  fmap2 _ (L2 x) = L2 x
  fmap2 g (R2 y) = R2 (g y)

data App t = App (t Int)
data R = C { x :: Int, y, z :: Bool }
data Mx = MA { mx :: Int } | MB Int
data S = S1 { sx :: Int } | S2 { sx :: Int }
type I = Int
data S' = S1' { sx' :: I } | S2' { sx' :: Int }

nil :: Set (Int -> Int)
nil = NilSet

first :: Eq a => Set a -> a
first (ConsSet a _) = a

same :: Set (Int -> Int) -> Set (Int -> Int)
same s = s

ua :: U (Int -> Int)
ua = UA

w :: App (T1 Maybe)
w = App (T1 (Just 1))

k :: T1 Maybe Int
k = T1 Nothing

main :: IO ()
main = do
  print (map (C0 True) "ab", first (ConsSet 'c' NilSet), x (C 1 True False), mx (MA 2))
  print (sx (S1 1) + sx (S2 2) + sx' (S1' 3) + sx' (S2' 4))
  case (same nil, ua, w, k) of _ -> return ()
