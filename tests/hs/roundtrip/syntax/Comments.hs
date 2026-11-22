{-# OPTIONS_GHC -fno-warn-tabs #-}
{- A nested {- comment -} at the head of the file, -- with a dash in it -}
module Comments (main) where   -- a comment after the header

{-# INLINE main #-}
-- | A comment, and an operator that is not one:
(-->) :: Int -> Int -> Int
a --> b = a {- inside an expression -} + b
(|--) = (-->)
-------------------------------------------------------------------------
main = print (1 --> 2) -- trailing
  {- a comment where layout would put a semicolon -}
  where
    -- a comment before the first item of a block
    x = "a string with -- and {- inside -}"   {- after -}
    y = 'ü' -- characters above ASCII in a literal and a comment: ü, €, 中
    z = "ü€中"
{- an unterminated-looking -- comment that is closed -}
-- the end, with no newline after it