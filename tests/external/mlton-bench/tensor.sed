# the tensor sizes of Main.one, [100,200,300,400,500] in MLton's benchmark: a
# 40-square tensor here, since one iteration at MLton's sizes allocates 787 GB
s/test_operator constructor operators \[100,200,300,400,500\]/test_operator constructor operators [40]/
# the elapsed times it prints allocate their digits: a clock that reads 0
# keeps the count the same on every machine (docs/testing.md)
s/^\( *\)fun timerRead () =$/\1fun timerRead () = (0 : LargeInt.int) (* the count oracle: a fixed clock *)\n\1fun timerReadUnused () =/
