{-# LANGUAGE PackageImports #-}
-- Data.Char (T10 chapter 16): base's functions (every one is monomorphic).
module Data.Char (
    Char, String, isControl, isSpace, isLower, isUpper, isAlpha,
    isAlphaNum, isPrint, isDigit, isOctDigit, isHexDigit, isLetter,
    isMark, isNumber, isPunctuation, isSymbol, isSeparator, isAscii,
    isLatin1, isAsciiUpper, isAsciiLower,
    GeneralCategory(UppercaseLetter, LowercaseLetter, TitlecaseLetter, ModifierLetter, OtherLetter, NonSpacingMark,
        SpacingCombiningMark, EnclosingMark, DecimalNumber, LetterNumber, OtherNumber, ConnectorPunctuation,
        DashPunctuation, OpenPunctuation, ClosePunctuation, InitialQuote, FinalQuote, OtherPunctuation, MathSymbol,
        CurrencySymbol, ModifierSymbol, OtherSymbol, Space, LineSeparator, ParagraphSeparator, Control, Format,
        Surrogate, PrivateUse, NotAssigned),
    generalCategory, toUpper, toLower, toTitle, digitToInt, intToDigit,
    ord, chr, showLitChar, lexLitChar, readLitChar
  ) where
import "base" Data.Char
