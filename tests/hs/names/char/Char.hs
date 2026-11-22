-- A program's own module Char (D36): its identity is Char, and the library's,
-- which the Prelude's closure reads, is haskell98:Char; neither meets the
-- other. nhc98's nofib/real/infer has a Maybe of its own in this way (E16).
module Char (Shout, shout, toUpper) where

type Shout = String

shout :: String -> Shout
shout s = s ++ "!"

-- not the library's toUpper
toUpper :: Char -> Char
toUpper c = c
