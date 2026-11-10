-- Derived instances (the Report's chapter 10; the haskell98 roadmap's M14,
-- D33's C): each class that can be derived, the contexts the checker infers
-- by 10.1's fixpoint, the least that make the fields' types instances, and
-- the methods HsDerive makes, checked as a user's instance.
module All () where

import Ix (Ix, range, index, inRange)

-- an enumeration: every class
data Colour = Red | Green | Blue deriving (Eq, Ord, Enum, Bounded, Ix, Show, Read)

-- a parameter only one field uses: the context names it alone
data Pair a b = Pair a Int deriving (Eq, Ord, Show, Read)

-- a parameter under a type constructor: the context is still simple
data Wrap a = Wrap (Maybe a) [a] deriving (Eq, Show)

-- a recursive type: the fixpoint
data Tree a = Leaf | Node (Tree a) a (Tree a) deriving (Eq, Ord, Show, Read)

-- a record, shown and read as C {f = v} (R41)
data Rec = Rec {name :: String, size :: Int} deriving (Eq, Show, Read)

-- an infix constructor, by its fixity (10.4)
infixl 6 :+:
data Sum = Int :+: Int deriving (Eq, Ord, Show, Read)

-- one constructor: Bounded and Ix by its fields
data Point = Point Int Bool deriving (Eq, Ord, Bounded, Ix, Show)

-- a newtype, as a data type (R23)
newtype Age = Age Int deriving (Eq, Ord, Show, Read)

-- a data type's own context (4.3.3): the derived instance's context has it
data (Eq a) => Set a = Set [a] deriving (Eq, Show)

-- uses, so that the instances are checked at work
check :: Bool
check = Red < Blue && [Red ..] == [minBound .. maxBound] && range (Red, Blue) == [Red, Green, Blue]
        && Pair 'a' 1 == Pair 'a' 1 && show (Wrap (Just 1) [2 :: Int]) /= ""
        && (read "Rec {name = \"x\", size = 3}" :: Rec) == Rec "x" 3
        && compare (1 :+: 2) (1 :+: 3) == LT && index (Point 0 False, Point 2 True) (Point 1 True) >= 0
        && Age 3 < Age 4 && (Node Leaf 'x' Leaf) > Leaf
