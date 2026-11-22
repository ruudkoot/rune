-- rows: cls.derive.newtype cls.derive.super.explicit cls.derive.super.derived cls.derive.classes der.superclass.explicit
-- Report 4.3.3: deriving gives instances of Eq, Ord, Enum, Bounded, Show and Read, for data and newtype, the superclass
-- derived alongside or given by hand.
module Main (main) where

data T = A | B | C deriving (Eq, Ord, Enum, Bounded, Show, Read)
newtype N = N Int deriving (Eq, Ord, Show, Read)
data U = U deriving Ord
instance Eq U where
  _ == _ = True

main :: IO ()
main = print ([minBound .. maxBound :: T], A < B, read "C" :: T, N 1 == N 1, U <= U)
