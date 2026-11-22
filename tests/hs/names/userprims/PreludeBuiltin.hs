-- A program's own PreludeBuiltin: its identity is PreludeBuiltin, and the
-- library's module of primitives, haskell98:PreludeBuiltin, which a program
-- cannot import, is another, which the Prelude imports.
module PreludeBuiltin (primAnswer, primError) where

primAnswer :: Int
primAnswer = 42

-- not the library's primError
primError :: String -> String
primError s = "error: " ++ s
