-- Two types that mention each other are one recursive group: an edit of either moves both, and what mentions
-- either.
module All (T(..), U(..), size, unrelated) where

data T = L | N U
data U = M T

size :: T -> Int
size _ = 0

unrelated :: Bool
unrelated = True
