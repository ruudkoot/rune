-- rows: lex.comment.nobrace lex.comment.tripledash lex.comment.unanalysed lex.comment.firstclose lex.comment.nested.dashes lex.comment.interfere.line lex.comment.pragma
-- Report 2.3: a nested comment begins with {- and ends with -}, nothing in it is lexed ("The comment itself is not
-- lexically analysed"), the first unmatched -} ends it, dashes mean nothing in it, {- and -} in a line
-- comment inside one still nest, and pragmas are nested comments.
module Main (main) where

{-# FOO and other pragmas #-}

{--- three dashes open a nested comment, not a line comment -}

{- an unclosed " string and ' char are harmless here -}

{- -- a line comment inside: this closes on this line -}

{- -- {- this opens a level that the next line closes
-} still in the comment -}

main :: IO ()
main = {- -} print {--} 1 {- -}
