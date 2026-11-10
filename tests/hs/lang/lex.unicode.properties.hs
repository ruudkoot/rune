-- Report 2.2, 2.4: identifiers above ASCII by their categories: a small letter (Ll) begins a variable, a large
-- one (Lu) a constructor, a digit (Nd) may follow, a symbol (Sm) makes an operator, a space (Zs) separates.
module Main (main) where

data Été = Été Int deriving Show

évaluer :: Int -> Int
évaluer x٣ = x٣ + 1

(∘∘) :: (b -> c) -> (a -> b) -> a -> c
f ∘∘ g = \x -> f (g x)

main :: IO ()
main = print (Été (évaluer 1), (évaluer ∘∘ évaluer) 5)
