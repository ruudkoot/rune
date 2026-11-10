-- rows: std.tuple.tycon std.seq.type std.text.reads std.text.shows std.num.types
-- Report 6.1.2, 6.1.4, 6.2, 6.3.3, 6.4: String is [Char], (Int,Bool,Int) is (,,) Int Bool Int, seq is a -> b -> b, ReadS and
-- ShowS are their expansions, and Int, Integer, Float and Double are the Prelude's.
module Main (main) where

s :: String -> [Char]
s x = x

t :: (Int, Bool, Int) -> (,,) Int Bool Int
t x = x

r :: ReadS Int -> (String -> [(Int, String)])
r f = f

w :: ShowS -> (String -> String)
w f = f

nums :: (Int, Integer, Float, Double)
nums = (1, 2, 3, 4)

main :: IO ()
main = print (s "a", t (1, True, 2), seq 'c' True, seq () (1 :: Int), nums)
