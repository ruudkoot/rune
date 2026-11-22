-- rows: lex.string.form lex.string.squote lex.string.chardquote lex.esc.form
-- Report 2.6: char -> ' (graphic<' | \> | space | escape<\&>) '; string -> " {graphic<" | \> | space | escape | gap} ";
-- escape -> \ ( charesc | ascii | decimal | o octal | x hexadecimal ): one of each form.
module Main (main) where

main :: IO ()
main = print (['a', ' ', '\n', '"', '\'', '\\', '\a', '\b', '\f', '\r', '\t', '\v',
               '\NUL', '\SOH', '\DEL', '\^A', '\^@', '\^[', '\^\', '\^]', '\^^', '\^_',
               '\65', '\o101', '\x41'],
              ["", "Hello", "'", "\"", "\SO\&H", "a\&b"])
