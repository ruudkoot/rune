-- rows: std.enum.derive std.bounded.derive.enum std.bounded.derive.single der.enum.succ der.enum.pred der.enum.toenum der.enum.fromenum der.enum.enumfrom der.enum.enumfromthen.up der.enum.enumfromthen.down der.enum.enumfromthen.equal der.enum.enumfromto der.enum.enumfromto.empty der.enum.enumfromthento der.enum.example.1 der.enum.example.2 der.enum.singleton der.bounded.methods der.bounded.enum.min der.bounded.enum.max der.bounded.single der.bounded.example.pair der.newtype.bounded der.newtype.show
-- Report 10.2, 10.3: a derived Enum numbers its constructors from 0 and its sequences stop at the last; the Report's
-- Color; a derived Bounded gives the first and last constructor, or each field's bound; a newtype's are its field's.
module Main (main) where

data Color = Red | Orange | Yellow | Green deriving (Show, Eq, Enum, Bounded)

data Single = Only deriving (Show, Enum)
data S = S Bool Char deriving (Show, Bounded)
data Pair a b = Pair a b deriving (Show, Bounded)
newtype N = N Bool deriving (Show, Bounded)

main :: IO ()
main = do
  print (map fromEnum [Red, Orange, Yellow, Green], succ Red, pred Orange, toEnum 2 :: Color)
  print ([Orange ..], [Red, Yellow ..], [Green, Yellow ..], take 3 [Red, Red ..])
  print ([Orange .. Green], [Green .. Red], [Red, Yellow .. Green], [Green, Orange .. Red])
  print ([Red ..] == [minBound .. maxBound], [Only ..], minBound :: Color, maxBound :: Color)
  print (minBound :: S, maxBound :: Pair Bool Bool, minBound :: N, N True)
