-- rows: dec.newtype.recursive dec.newtype.context dec.newtype.instance dec.newtype.deriving dec.newtype.field R23
-- Report 4.2.3: a newtype has the representation of its field's type, may be recursive, may have a context (R23: the text
-- says nothing of what it means, and rhc takes it as data's), may have instances of its own, derives as data
-- does, and may name its one field.
module Main (main) where

newtype N = N Int
newtype L = L (Maybe (Int, L))
newtype Eq a => E a = E a
newtype D = D Int deriving (Eq, Ord, Show, Read)
newtype Age = Age { unAge :: Int }

instance Show N where
  show (N n) = "N " ++ show n

unN :: N -> Int
unN (N n) = n

end :: L
end = L Nothing

e :: E Int
e = E 1

main :: IO ()
main = print (N 1, unN (N 2), D 3 < D 4, read "D 5" :: D, unAge (Age 6))
