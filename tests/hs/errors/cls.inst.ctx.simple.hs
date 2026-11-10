-- Report 4.3.2: the instance context is an scontext: not Eq (f a).
module Main (main) where

class C a
data T f a = T
instance Eq (f a) => C (T f a)

main :: IO ()
main = return ()
