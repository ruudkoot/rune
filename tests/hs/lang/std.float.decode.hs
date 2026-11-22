-- rows: std.float.decode.zero std.float.decode.neg std.float.encode std.float.significand std.float.exponent std.float.exponent.zero std.float.scale std.num.table.float std.num.table.double R45
-- Report 6.4.6: decodeFloat gives m and n with m and n both zero or b^(d-1) <= |m| < b^d; encodeFloat inverts it;
-- significand, exponent and scaleFloat.
module Main (main) where

main :: IO ()
main = do
  print (decodeFloat (1.0 :: Double), decodeFloat (0 :: Double), decodeFloat (-1.0 :: Double), decodeFloat (1.0 :: Float))
  print (uncurry encodeFloat (decodeFloat (0.375 :: Double)) == (0.375 :: Double), uncurry encodeFloat (decodeFloat (6.5 :: Float)) == (6.5 :: Float))
  print (significand (8 :: Double), exponent (8 :: Double), exponent (0 :: Double), scaleFloat 2 (3.0 :: Double))
  print (let x = 12.5 :: Double in x == significand x * 2 ^^ exponent x)
