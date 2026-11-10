-- A program's own UnicodePrims, beside the library's haskell98:UnicodePrims,
-- which Char imports.
module UnicodePrims (primUnicodeMaxChar) where

primUnicodeMaxChar :: Int
primUnicodeMaxChar = 127
