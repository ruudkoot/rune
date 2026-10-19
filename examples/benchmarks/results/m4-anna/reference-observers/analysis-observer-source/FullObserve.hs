module FullObserve where
import qualified Main as A
import ReadTable
main=do
 table<-fmap rtReadTable(readFile"../source/runtime_files/anna_table")
 mapM_(\(profile,file)->do
   contents<-readFile("../source/"++file)
   let result=A.maStrictAn table [] contents
   writeFile("../full-"++profile++".reference")result
   print(profile,length result))
  [("smoke","anna.faststdin"),("normal","anna.stdin"),("large","anna.slowstdin")]
