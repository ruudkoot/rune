-- HsLint's replay of dictionaries (the roadmap's M16, D54; Faxen 2002, fig. 28): superclasses taken
-- through chains of two steps and more, the Prelude's and the program's own, and a class of several
-- methods used through a dictionary, with a default method and two instances, so that a superclass
-- path or a method's slot the checker gets wrong is seen by replay.
module Main (main) where

class Eq a => Named a where
  name :: a -> String
  rank :: a -> Int
  alike :: a -> a -> Bool
  alike x y = name x == name y

class Named a => Ranked a where
  best :: [a] -> a

data Colour = Red | Green | Blue deriving (Eq, Show)

instance Named Colour where
  name Red = "red"
  name Green = "green"
  name Blue = "blue"
  rank c = length (name c)

instance Ranked Colour where
  best = foldr1 (\x y -> if rank x >= rank y then x else y)

newtype Label = Label String deriving (Eq, Show)

instance Named Label where
  name (Label s) = s
  rank (Label s) = length s
  alike x y = rank x == rank y

-- three methods of the class through its dictionary, and its superclass's
describe :: Named a => a -> a -> String
describe x y = name x ++ show (rank y) ++ show (alike x y) ++ show (x == y)

-- Eq through Ranked and Named: two steps
sameRanked :: Ranked a => a -> a -> Bool
sameRanked x y = x == y && alike x y

-- Eq and Ord through Integral: three steps and two
eqIntegral :: Integral a => a -> a -> Bool
eqIntegral x y = x == y

ltIntegral :: Integral a => a -> a -> Bool
ltIntegral x y = x < y

-- Num through RealFloat: three steps
twice :: RealFloat a => a -> a
twice x = x + x

main :: IO ()
main = do
  print (describe Red Blue, describe (Label "ab") (Label "cd"))
  print (sameRanked Red Green, best [Red, Green, Blue])
  print (eqIntegral 3 (4 :: Int), ltIntegral 3 (4 :: Integer), twice (1.5 :: Double))
