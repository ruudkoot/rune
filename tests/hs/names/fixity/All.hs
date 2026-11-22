-- Fixity is an attribute of an entity, read after names (D29): a local
-- +++, of no fixity declaration, is infixl 9 whatever A's +++ is; A's is
-- infix 4 under any qualifier; a local fixity declaration is the local
-- operator's. Every expression here resolves, and none of them would if
-- fixity were read by the name as written.
module All () where

import qualified A
import A ((<+>), Pair(..))

-- the local +++ is infixl 9: (x +++ y) == y
f :: Int -> Int -> Bool
f x y = x +++ y == y
  where a +++ b = a

-- A's +++ is infix 4, as == is not: (x A.+++ y) || False
g :: Int -> Int -> Bool
g x y = x A.+++ y || False

-- a local fixity: <+> here is infixl 1, so a <+> b == c <+> d is (a <+> (b == c)) <+> d
h :: Bool -> Bool -> Bool -> Bool -> Bool
h a b c d = a <+> b == c <+> d
  where
    infixl 1 <+>
    p <+> q = p && q

-- a constructor operator in a pattern, by A's fixity: x :& y : rest is (x :& y) : rest
k :: [Pair] -> Int
k (x :& y : _) = x + y
k _ = 0

-- negation binds as tightly as + and -, so - x + y is (- x) + y, and x <+> [- 1] parses
n :: Int -> Int -> [Int]
n x y = [- x + y] <+> [- 1]
