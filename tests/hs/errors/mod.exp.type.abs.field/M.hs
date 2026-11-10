module M (T, mk) where

data T = C Int | D { fld :: Int }

mk :: T
mk = C 1
