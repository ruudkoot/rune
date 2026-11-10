-- Report 1.4: one spelling in each namespace that permits it: T a type, a constructor and a module's name's
-- part; t a variable and a type variable.
module Main (main) where

data T = T

t :: t -> t
t t = t

u :: T
u = T

main :: IO ()
main = return ()
