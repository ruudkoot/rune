module M (T, Con2(..), mk) where

data T = Hidden | Shown
data Con2 = Con | Two

mk :: T
mk = Shown
