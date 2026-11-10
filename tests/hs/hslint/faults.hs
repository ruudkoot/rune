-- HsLint's comparison and replay (the roadmap's M16, D54): this program's dump, read back as a record's
-- claims, holds, and so does its checker's evidence; each fault of RHC_HSLINT_FAULT reads the first claim
-- or record its rule checks corrupted, which that rule refuses: a kind, a derived context, a type,
-- Rule 1, a signature, a default's classes, Rule 2's default at the module's end, a group's default, and
-- Faxen's bindg and dictionaries, an instance's superclasses and methods, a class's slots, and rhc's rule of cycles.
module Main (main) where

data T a = T a deriving (Eq, Show)

newtype N = N Int deriving (Eq, Show)

instance Num N where
  N a + N b = N (a + b)
  N a * N b = N (a * b)
  negate (N a) = N (negate a)
  abs k = k
  signum k = k
  fromInteger k = N (fromInteger k)

n = 2
m = n + 1.5

size :: Int
size = 3

eqList :: Eq a => [a] -> [a] -> Bool
eqList x y = x == y

ordEq :: Ord a => a -> a -> Bool
ordEq x y = x == y

main :: IO ()
main = print (T 10 == T 20, m, size, eqList [1] [2], ordEq 'a' 'b', N 1 + 2)
