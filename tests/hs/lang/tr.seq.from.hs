-- rows: std.enum.seq tr.seq.fromthen tr.seq.fromto tr.seq.fromthento exp.seq.instance
-- Report 3.10: [e1..], [e1,e2..], [e1..e3] and [e1,e2..e3] are enumFrom, enumFromThen, enumFromTo and enumFromThenTo:
-- a user instance's methods are obeyed, whatever they do.
module Main (main) where

data E = E Int deriving Show

instance Enum E where
  toEnum = E
  fromEnum (E n) = n
  enumFrom (E n) = [E n, E 100]
  enumFromThen (E a) (E b) = [E a, E b, E 200]
  enumFromTo (E a) (E b) = [E b, E a]
  enumFromThenTo (E a) (E b) (E c) = [E c, E b, E a]

main :: IO ()
main = do
  print [E 1 ..]
  print [E 1, E 2 ..]
  print [E 1 .. E 2]
  print [E 1, E 2 .. E 3]
