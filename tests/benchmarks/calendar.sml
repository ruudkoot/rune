structure CalendarPilot =
struct
 structure N=BenchCalendarFn(BenchNeed)
 structure S=BenchCalendarFn(BenchStrict)
 val _=T.check("calendar/leap-rules",fn()=>not(N.leap 1900)andalso N.leap 2000 andalso N.leap 2024)
 val _=T.check("calendar/weekday",fn()=>N.jan1st 2024=1 andalso N.jan1st 2000=6)
 val _=T.check("calendar/length",fn()=>N.size 1994=2888 andalso S.size 1994=2888)
 val _=T.check("calendar/variants",fn()=>N.text 2000=S.text 2000)
 val _=T.check("calendar/payload-demand",fn()=>N.length(N.Q.cons(BenchNeed.delay(fn()=>raise Fail "unneeded char"))(N.Q.empty()))=1)

 val _=T.check("calendar/group-prefix-defers-tail",fn()=>
   let val input=N.Q.cons(N.Q.value 1)(BenchNeed.delay(fn()=>raise Fail "unneeded group tail"))
   in case BenchNeed.force(N.group 7 input)of N.Q.Cons _=>true | _=>false end)

 fun fixture year=let val input=TextIO.openIn(Int.toString year^".txt")
                      val text=TextIO.inputAll input
                      val _=TextIO.closeIn input
                  in text end
 val _=List.app(fn year=>T.check("calendar/full-render-"^Int.toString year,fn()=>
   let val expected=fixture year in N.text year=expected andalso S.text year=expected end))
   [1,4,100,400,1900,1994,2000,2024,9999,11993,51993]
 val _=T.check("calendar/justification-keeps-payload-lazy",fn()=>
   N.length(N.cjustify 7(N.Q.cons(BenchNeed.delay(fn()=>raise Fail "unneeded glyph"))(N.Q.empty())))=7)
 val _=T.check("calendar/unlines-keeps-payload-lazy",fn()=>
   N.length(N.unlines(N.singleton(N.Q.cons(BenchNeed.delay(fn()=>raise Fail "unneeded glyph"))(N.Q.empty()))))=2)
 val _=T.check("calendar/negative-padding",fn()=>String.implode(N.Q.toList(N.cjustify 1(N.chars "abc")))="abc")

 val _=T.check("calendar/negative-drop",fn()=>N.Q.toList(N.drop ~1(N.Q.fromList[1,2]))=[1,2])
end
