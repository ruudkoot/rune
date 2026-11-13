-- An operator's fixity is in its fingerprint (H6): it moves alone.
module All ((<+>), plain) where

infixr 6 <+>

(<+>) :: Int -> Int -> Int
a <+> b = a + b

plain :: Int -> Int
plain = id
