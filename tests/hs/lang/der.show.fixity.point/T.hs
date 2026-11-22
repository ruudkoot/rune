module T (E(..)) where

infixl 6 :+:
infixl 7 :*:

data E = L Int | E :+: E | E :*: E deriving Show
