val ()=if not(RuneForeign.available()) then () else
  let val windows=List.exists(fn(name,value)=>name="sysname" andalso value="Windows")(Posix.ProcEnv.uname())
      val library=RuneForeign.openLibrary(if windows then "msvcrt.dll" else "libc.so.6")
      val searchSymbol=RuneForeign.symbol(library,"strchr")
      val freeSymbol=RuneForeign.symbol(library,"free")
      val searchCall=RuneForeign.prepare{symbol=searchSymbol,abi=0,result=RuneForeign.Pointer,arguments=[RuneForeign.Pointer,RuneForeign.SInt32]}
      val freeCall=RuneForeign.prepare{symbol=freeSymbol,abi=0,result=RuneForeign.Void,arguments=[RuneForeign.Pointer]}
      val input=RuneForeign.allocate 0w6
      val ()=RuneForeign.write(input,0w0,"hello\000")
      val pointer=valOf(#pointer(RuneForeign.invoke(searchCall,[RuneForeign.Address(SOME input),RuneForeign.Signed 101])))
      val view=RuneForeign.view(input,0w1,0w5)
      val ()=if RuneForeign.sameAddress(pointer,view) andalso RuneForeign.isLive pointer then () else raise Fail "pointer identity"
      val ()=((ignore(RuneForeign.dispose{resource=pointer,call=freeCall,arguments=[RuneForeign.Address(SOME pointer)],failure=RuneForeign.NoFailure});
          raise Fail "native destructor accepted Rune-owned storage")handle RuneForeign.Error{message,...}=>
          if String.isSubstring "Rune-owned storage" message then () else raise Fail message)
      val ()=RuneForeign.release pointer
      val ()=if not(RuneForeign.isLive pointer) then () else raise Fail "retired identity remained live"
      val ()=List.app RuneForeign.release[view,input,freeCall,searchCall,freeSymbol,searchSymbol,library]
  in () end
val ()=print "native ownership uses guarded identities\n"
