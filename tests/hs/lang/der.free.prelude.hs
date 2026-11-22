-- Report 10: derived code uses the Prelude's entities whatever is in scope: &&, showParen and lex redefined.
module Main (main) where

import Prelude hiding ((&&), showParen, lex)

(&&) :: Int
(&&) = 0

showParen :: Int
showParen = 0

lex :: Int
lex = 0

data P = P Int Bool deriving (Eq, Ord, Show, Read)

main :: IO ()
main = print (P 1 True == P 1 True, P 1 False < P 1 True, Just (P (-1) True), read "P 3 False" :: P)
