-- A unit made after A, with a derived instance whose Core binds fresh
-- names: numbered from a range of its own, they are the same whether A was
-- checked in the same session or taken from the store.
module B where

import A

data T a = T (Box a) Int deriving Show

t :: T Int
t = T (Box (twice (+ 1) 1)) 2
