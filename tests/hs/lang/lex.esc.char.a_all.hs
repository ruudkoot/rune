-- rows: lex.esc.char.b lex.esc.char.f lex.esc.char.n lex.esc.char.r lex.esc.char.t lex.esc.char.v lex.esc.char.backslash lex.esc.char.dquote lex.esc.char.squote lex.esc.char.amp lex.esc.decimal lex.esc.octal lex.esc.hex lex.esc.munch lex.esc.soh lex.esc.soampersandh lex.esc.numampersand lex.esc.ctrl.upper lex.esc.ctrl.at lex.esc.ctrl.lbracket lex.esc.ctrl.backslash lex.esc.ctrl.rbracket lex.esc.ctrl.caret lex.esc.ctrl.underscore lex.esc.ascii.nul lex.esc.ascii.soh lex.esc.ascii.stx lex.esc.ascii.etx lex.esc.ascii.eot lex.esc.ascii.enq lex.esc.ascii.ack lex.esc.ascii.bel lex.esc.ascii.bs lex.esc.ascii.ht lex.esc.ascii.lf lex.esc.ascii.vt lex.esc.ascii.ff lex.esc.ascii.cr lex.esc.ascii.so lex.esc.ascii.si lex.esc.ascii.dle lex.esc.ascii.dc1 lex.esc.ascii.dc2 lex.esc.ascii.dc3 lex.esc.ascii.dc4 lex.esc.ascii.nak lex.esc.ascii.syn lex.esc.ascii.etb lex.esc.ascii.can lex.esc.ascii.em lex.esc.ascii.sub lex.esc.ascii.esc lex.esc.ascii.fs lex.esc.ascii.gs lex.esc.ascii.rs lex.esc.ascii.us lex.esc.ascii.sp lex.esc.ascii.del lex.gap.form lex.gap.ignored lex.gap.multiline lex.string.list R14
-- Report 2.6: every escape of a character or string literal: the named ones, decimal, octal and hexadecimal (read to the
-- longest), \& and its use to end a number or \SO before H, the control escapes \^@ to \^_, the ASCII names, and
-- gaps, on one line and over several; a string is a list of characters.
module Main (main) where

main :: IO ()
main = do
  print (map fromEnum "\a\b\f\n\r\t\v\\\"\'")
  print ("\&" == "", map fromEnum "\95\o137\x37")
  print ("\0000000065" == "A", length "\1234")
  print (length "\SOH", map fromEnum "\SO\&H", map fromEnum "\123\&4")
  print (map fromEnum "\^A\^B\^C\^D\^E\^F\^G\^H\^I\^J\^K\^L\^M\^N\^O\^P\^Q\^R\^S\^T\^U\^V\^W\^X\^Y\^Z")
  print (map fromEnum "\^@\^[\^\\^]\^^\^_")
  print (map fromEnum "\NUL\SOH\STX\ETX\EOT\ENQ\ACK\BEL\BS\HT\LF\VT\FF\CR\SO\SI\DLE\DC1\DC2\DC3\DC4\NAK\SYN\ETB\CAN\EM\SUB\ESC\FS\GS\RS\US\SP\DEL")
  print ("ab\   \cd" == "abcd", "ab\
          \cd", "ab" == ['a', 'b'])
