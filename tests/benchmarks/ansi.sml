structure BenchAnsiTests =
struct
 structure N=BenchAnsiFn(BenchNeed)
 structure S=BenchAnsiFn(BenchStrict)
 fun text s=N.Q.fromList(String.explode s)
 fun output stream=String.implode(N.Q.toList stream)
 fun entered s=output(N.readAt(1,1)3(fn name=>N.writeString name N.finish)(text s))
 val prefix="\027[1;1H___\027[1;1H"
 val _=T.eq T.string("ansi/empty-eof",prefix,fn()=>entered "")
 val _=T.eq T.string("ansi/newline",prefix,fn()=>entered "\nignored")
 val _=T.eq T.string("ansi/backspace",prefix^"ab\008_\008CaC",fn()=>entered "ab\008C\n")
 val _=T.eq T.string("ansi/delete",prefix^"ab\008_\008CaC",fn()=>entered "ab\127C\n")
 val _=T.eq T.string("ansi/empty-delete-bell",prefix^"\007",fn()=>entered "\008\n")
 val _=T.eq T.string("ansi/overlong-bells",prefix^"abc\007\007abc",fn()=>entered "abcde\n")
 val _=T.eq T.string("ansi/press-key-discards-one", "bc",fn()=>output(N.pressAnyKey(fn input=>input)(text "abc")))
 val _=T.eq T.string("ansi/unread", "abc",fn()=>output(N.unreadChar #"a"(fn input=>input)(text "bc")))
 val _=T.eq T.string("ansi/zero-composition-identity", "abc",fn()=>output(N.run 0(text "abc")))
 val _=T.check("ansi/lazy-strict-composition",fn()=>output(N.run 3(N.Q.empty()))=String.implode(S.Q.toList(S.run 3(S.Q.empty()))))
 val _=T.check("ansi/lazy-prefix-defers-continuation",fn()=>
   N.Q.head(N.writeString[ #"X"](fn _=>raise Fail "unneeded output")(N.Q.empty()))= #"X")
 val _=T.check("ansi/strict-prefix-demands-continuation",fn()=>
   ((S.writeString[ #"X"](fn _=>raise Fail "demanded output")(S.Q.empty());false)handle Fail _=>true))

 val _=T.check("ansi/lazy-prefix-defers-EOF-callback",fn()=>
   N.Q.head(N.readAt(1,1)3(fn _=>raise Fail "unneeded EOF callback")(text "X"))= #"\027")
 val _=T.check("ansi/EOF-callback-demanded-after-prefix",fn()=>
   ((N.Q.toList(N.readAt(1,1)3(fn _=>raise Fail "needed EOF callback")(text ""));false)handle Fail _=>true))
end
