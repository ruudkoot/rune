-- rows: lex.ident.namespaces lex.large.asc lex.digit.asc lex.varid lex.conid lex.ident.case lex.ident.underscore lex.small.underscore lex.ident.prose lex.names.six R8
-- Report 2.4: varid -> (small {small | large | digit | '})<reservedid>; conid -> large {small | large | digit | '};
-- small includes _, which "is treated as a lower-case letter" and may begin an identifier (the production, over
-- the prose of R8). Identifiers are case sensitive: name, naMe and Name are three.
module Main (main) where

data Name = Name | Ab1' | A_b

class Tycls a where
  method :: a -> Int

instance Tycls Name where
  method _ = 0

identity :: _a -> _a
identity x_ = x_

main :: IO ()
main = print (a1 + aB + a_b + a' + a''b + _x + __ + name + naMe + method Name + identity 0)
  where
    a1 = 1
    aB = 2
    a_b = 3
    a' = 4
    a''b = 5
    _x = 6
    __ = 7
    name = 8
    naMe = 9
