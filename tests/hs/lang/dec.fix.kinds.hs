-- rows: dec.fix.default.digit dec.fix.default.none dec.fix.default.backquote dec.fix.local dec.fix.conop
-- Report 4.4.2: infixl and infixr nest as they say; a declaration with no digit is level 9; an operator with none is
-- infixl 9, by name or in backquotes; a let may declare its operators' fixity; constructors' too.
module Main (main) where

infixl 6 -.
infixr 6 -:

(-.), (-:) :: Int -> Int -> Int
a -. b = a - b
a -: b = a - b

infixl +++

(+++) :: Int -> Int -> Int
a +++ b = a * 10 + b

(***) :: Int -> Int -> Int
a *** b = a * 10 + b

f :: Int -> Int -> Int
f a b = a * 100 + b

infixr 5 :+
data E = Int :+ E | Z deriving Show

main :: IO ()
main = do
  print (1 -. 2 -. 3, 1 -: 2 -: 3)
  print (2 +++ 3 ^ 2, 2 * 3 *** 4, 1 *** 2 *** 3, 2 * 3 `f` 4)
  print (let { infixr 5 +^; a +^ b = a - b } in 10 +^ 3 +^ 2 :: Int)
  print (1 :+ 2 :+ Z)
