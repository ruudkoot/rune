{-# LANGUAGE PackageImports #-}
-- Foreign.C.String (T10 chapter 27): base's (monomorphic).
module Foreign.C.String (
    CString, CStringLen, peekCString, peekCStringLen, newCString,
    newCStringLen, withCString, withCStringLen, charIsRepresentable,
    castCharToCChar, castCCharToChar, castCharToCUChar, castCUCharToChar,
    castCharToCSChar, castCSCharToChar, peekCAString, peekCAStringLen,
    newCAString, newCAStringLen, withCAString, withCAStringLen, CWString,
    CWStringLen, peekCWString, peekCWStringLen, newCWString,
    newCWStringLen, withCWString, withCWStringLen
  ) where
import "base" Foreign.C.String
