-- rows: std.unit.eq std.unit.ord std.unit.bounded std.unit.enum std.unit.read std.unit.show std.fun.simple
-- Report 6.1.5: data () = () deriving (Eq, Ord, Bounded, Enum, Read, Show); 6.1.6: the Prelude's simple functions.
module Main (main) where

main :: IO ()
main = do
  print (case () of () -> 1 :: Int, () == (), compare () (), maxBound :: (), [() ..])
  print (read "()" :: (), show ())
  print (id 1 :: Int, const 1 (2 :: Int) :: Int, ((+ 1) . (* 2)) 3 :: Int, flip (-) 1 3 :: Int, ($) negate 3 :: Int)
