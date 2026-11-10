-- rows: std.char.enum std.char.bounded std.char.read std.char.show std.char.eq std.char.ord std.char.enumclass std.char.toenum std.char.ascii.repr std.char.equiv.a std.char.equiv.b std.char.equiv.f std.char.equiv.r std.char.equiv.t std.char.equiv.v std.char.equiv.n std.string.abbrev R38
-- Report 6.1.2: Char is an enumeration whose values are Unicode characters, minBound '\0', with the classes' instances;
-- '\1', '\SOH' and '\^A' are one character, \a \b \f \r \t \v \n the controls named; a String is a [Char].
module Main (main) where

f :: Char -> Int
f 'x' = 1
f _ = 0

main :: IO ()
main = do
  print (fromEnum 'a', fromEnum (toEnum 1000 :: Char), minBound :: Char)
  print (f 'x', f 'y', read "'a'" :: Char)
  print (show 'a', 'a' == 'a', 'a' < 'b')
  print ['a' .. 'e']
  print (toEnum (fromEnum 'q') :: Char)
  print ('\1' == '\SOH', '\SOH' == '\^A')
  print ['\a' == '\BEL', '\b' == '\BS', '\f' == '\FF', '\r' == '\CR', '\t' == '\HT', '\v' == '\VT', '\n' == '\LF']
  print ("A string" == ['A', ' ', 's', 't', 'r', 'i', 'n', 'g'])
