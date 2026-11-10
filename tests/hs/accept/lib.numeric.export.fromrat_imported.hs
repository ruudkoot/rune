-- rows: lib.numeric.export.showsigned lib.numeric.export.showintatbase lib.numeric.export.showint lib.numeric.export.showoct lib.numeric.export.showhex lib.numeric.export.readsigned lib.numeric.export.readint lib.numeric.export.readdec lib.numeric.export.readoct lib.numeric.export.readhex lib.numeric.export.floattodigits lib.numeric.export.showefloat lib.numeric.export.showffloat lib.numeric.export.showgfloat lib.numeric.export.showfloat lib.numeric.export.readfloat lib.numeric.export.lexdigits
-- Report 14: module Numeric exports each of these: an explicit import of every one compiles, and each name is used.
module Main (main) where

import Numeric (fromRat, showSigned, showIntAtBase, showInt, showOct, showHex, readSigned, readInt, readDec, readOct, readHex, floatToDigits, showEFloat, showFFloat, showGFloat, showFloat, readFloat, lexDigits)

v0 _ = fromRat

v1 _ = showSigned

v2 _ = showIntAtBase

v3 _ = showInt

v4 _ = showOct

v5 _ = showHex

v6 _ = readSigned

v7 _ = readInt

v8 _ = readDec

v9 _ = readOct

v10 _ = readHex

v11 _ = floatToDigits

v12 _ = showEFloat

v13 _ = showFFloat

v14 _ = showGFloat

v15 _ = showFloat

v16 _ = readFloat

v17 _ = lexDigits

main :: IO ()
main = return ()
