-- Report 10.4: derived Read uses no associativity: 1 :$ 2 :$ NT without parentheses does not parse.
module Main (main) where

infixr 9 :$
data E = NT | Int :$ E deriving (Show, Read)

main :: IO ()
main = print (read "1 :$ 2 :$ NT" :: E)
