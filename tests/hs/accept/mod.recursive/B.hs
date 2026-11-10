module B (Tb(..), fb, cb) where

import A

data Tb = Tc Ta | Td

fb :: Int -> Int
fb n = fa n + 1

cb :: Tb -> Int
cb (Tc t) = ca t
cb Td = 0
