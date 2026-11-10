-- Report 2.6: char -> ' (graphic<...> | space | escape<\&>) ': space alone of the white
-- characters stands raw in a character, so a raw tab does not.
module Main (main) where

c :: Char
c = '	'

main :: IO ()
main = return ()
