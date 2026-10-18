val amount=case TextIO.inputLine TextIO.stdIn of NONE=>raise Fail "missing shift amount"
 |SOME text=>valOf(Int.fromString text)
val actual=BenchDomWord.bit amount
val _=print("Word64 bit "^Int.toString amount^" = "^Word64.toString actual^"\n")
val _=if amount=0 andalso actual=0w1 then
 print"PASS zero shift\nSUMMARY 1 checks, 0 failed\n"
 else print"FAIL zero shift\nSUMMARY 1 checks, 1 failed\n"
