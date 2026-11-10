-- Report 4.3.2: the superclass instances' contexts are implied by the instance's: the Report's invalid pair.
module Main (main) where

class (Eq a, Show a) => Foo a
class Foo a => Bar a
instance Num a => Foo [a]
instance (Eq a, Show a) => Bar [a]

main :: IO ()
main = return ()
