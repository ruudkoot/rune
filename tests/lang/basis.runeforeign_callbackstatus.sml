val ()=if not(RuneForeign.available()) then () else
  let val callback=RuneForeign.callback{abi=0,result=RuneForeign.SInt32,arguments=[],
        function=fn _=>RuneForeign.Signed 0,failure=RuneForeign.Default(RuneForeign.Signed ~1)}
      val initial=RuneForeign.callbackStatus{callback=callback,reset=false}
      val reset=RuneForeign.callbackStatus{callback=callback,reset=true}
      val ()=if initial={rejected=0w0,first=NONE} andalso reset=initial then () else raise Fail "initial callback status"
      val ()=RuneForeign.release callback
      val ()=if (ignore(RuneForeign.callbackStatus{callback=callback,reset=false});false)handle RuneForeign.Error _=>true
        then () else raise Fail "stale callback status"
  in () end
val ()=print "callback fault snapshots reset atomically and retain resource guards\n"
