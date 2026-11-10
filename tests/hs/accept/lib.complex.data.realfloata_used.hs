-- Report 13.1: data (RealFloat a) => Complex a = !a :+ !a deriving (Eq, Read, Show): Complex Float and Complex
-- Double, the constructor in patterns and expressions, the derived classes, and the kind * -> *.
module Main (main) where

import Complex

data K f = K (f Double)

k :: K Complex
k = K (1 :+ 2)

f :: Complex Float -> Float
f (x :+ _) = x

g :: Complex Double -> (Bool, String, Complex Double)
g z = (z == z, show z, read (show z))

main :: IO ()
main = return ()
