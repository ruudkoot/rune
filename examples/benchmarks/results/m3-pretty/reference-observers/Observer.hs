module Main where
import Pretty
import System.Environment
main=do
 [sw,sn]<-getArgs
 let stuff=ppAboves[ppBesides[ppInt(-42),ppChar '@',ppStr "This is a string"],pp'SP,
                    ppHang(ppStr "This is the label")8(ppCat(take(read sn)(repeat(ppStr "xxxxx"))))]
 putStr(ppShow(read sw)stuff++"\n")
