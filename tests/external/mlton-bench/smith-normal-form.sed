# dim 35 in MLton's benchmark takes hours in the interpreter (over 2 TB
# allocated); dim 26 stands for it, and the entry check that assumes dim 35
# is off
s/let val dim = 35$/let val dim = 26 (* 35 in MLton's benchmark; reduced, so the entry check below is off *)/
s/else raise Fail "bug"$/else () (* the check assumes dim = 35 *)/
