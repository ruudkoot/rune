(* The production SML frontend derives selected layouts; separately compiled
   C prints measurements of the unchanged headers for byte-for-byte comparison. *)
structure HeaderLayout =
struct
  fun read file= #text(CFiles.read file)
  fun write(file,text)=let val output=TextIO.openOut file in TextIO.output(output,text);TextIO.closeOut output end
  fun field name value=case Json.member(name,value) of SOME x=>x | NONE=>raise Fail("missing " ^ name)
  fun string(Json.String s)=s | string _=raise Fail "expected string"
  fun array(Json.Array a)=a | array _=raise Fail "expected array"
  fun strings value=List.map string(array value)
  fun mapi function values=ListPair.map function(List.tabulate(length values,fn i=>i),values)
  fun valid text=String.size text>0 andalso List.all(fn c=>Char.isAlphaNum c orelse c= #"_" orelse c= #".")(String.explode text)
  val fields=[("SDL_Event",["type","window.windowID","window.type","window.data1","window.data2","key.windowID","key.key","key.scancode","key.mod","key.down","key.repeat","text.windowID","text.text","motion.windowID","motion.state","motion.x","motion.y","button.windowID","button.button","button.clicks","button.x","button.y","button.down"]),
    ("SDL_Surface",["flags","format","w","h","pitch","pixels"]),("SDL_Rect",["x","y","w","h"]),("SDL_FRect",["x","y","w","h"]),
    ("WNDCLASSEXW",["cbSize","style","lpfnWndProc","cbClsExtra","cbWndExtra","hInstance","hIcon","hCursor","hbrBackground","lpszMenuName","lpszClassName","hIconSm"]),
    ("CREATESTRUCTW",["lpCreateParams","hInstance","hMenu","hwndParent","cy","cx","y","x","style","lpszName","lpszClass","dwExStyle"]),
    ("MSG",["hwnd","message","wParam","lParam","time","pt.x","pt.y"]),("POINT",["x","y"]),("RECT",["left","top","right","bottom"]),
    ("PAINTSTRUCT",["hdc","fErase","rcPaint.left","rcPaint.top","rcPaint.right","rcPaint.bottom","fRestore","fIncUpdate","rgbReserved"])]
  val helpers=[("LOWORD",["0","0xFFFFFFFFULL","0x123456789ABCDEF0ULL"]),
    ("HIWORD",["0","0xFFFFFFFFULL","0x123456789ABCDEF0ULL"]),
    ("RGB",["0,0,0","255,128,1","257,258,259"]),
    ("GetRValue",["0","0xFFFFFFFFU","0x00A1B2C3U"]),
    ("GetGValue",["0","0xFFFFFFFFU","0x00A1B2C3U"]),
    ("GetBValue",["0","0xFFFFFFFFU","0x00A1B2C3U"]),
    ("GET_X_LPARAM",["(LPARAM)0","(LPARAM)0x8000FFFFU","(LPARAM)0x7FFF8000U"]),
    ("GET_Y_LPARAM",["(LPARAM)0","(LPARAM)0x8000FFFFU","(LPARAM)0x7FFF8000U"])]
  fun main(profilePath::inventoryPath::output::roots)=
    let val profile=ForeignTarget.decode{file=profilePath,text=read profilePath}
        val inventory=Json.decode(read inventoryPath)
        val headers=strings(field "headers" inventory)
        val includes="#define SDL_MAIN_HANDLED 1\n" ^ String.concat(List.map(fn h=>"#include <" ^ h ^ ">\n")headers)
        val names=strings(field "requiredTypes" inventory)
        val constants=List.map(fn v=>let val name=string(field "foreign" v) in ("constant." ^ name,name) end)(array(field "constants" inventory))
        val probes=constants @ (case Json.member("helpers",inventory) of NONE=>[] | SOME _=>
          List.concat(List.map(fn(name,arguments)=>mapi(fn(i,args)=>("helper." ^ name ^ "." ^ Int.toString i,name ^ "(" ^ args ^ ")"))arguments)helpers))
        val input=includes ^ String.concat(mapi(fn(i,(_,n))=>"unsigned long long runeffi_constant_" ^ Int.toString i ^ " = (" ^ n ^ ");\n")probes)
        val preprocessed=CPreprocess.run{source={file=inventoryPath ^ ".probe.c",text=input},predefined= #predefined profile,
          resolve=CFiles.resolver roots,width=64,maxDepth=256,maxExpansions=10000000}
        val declarations= #declarations(CParse.translationUnit{tokens= #tokens preprocessed,predefinedTypes=[]})
        val environment=CAnalysis.create{target= #analysis profile,declarations=declarations}
        val at={file=inventoryPath,line=1,column=1}
        val expected=ref([]:string list) val native=ref([]:string list)
        fun emit(label,value,expression)=
          (expected:=(label ^ "=" ^ IntInf.toString value ^ "\n"):: !expected;
           native:=("printf(\"" ^ label ^ "=%llu\\n\",(unsigned long long)(" ^ expression ^ "));\n"):: !native)
        fun one name=
          let val ()=if valid name then () else raise Fail "invalid fixture type"
              val layout=CAnalysis.layout environment{ty=CParse.Named name,source=at}
              val ()=emit(name ^ ".size",CLayout.size layout,"sizeof(" ^ name ^ ")")
              val ()=emit(name ^ ".align",IntInf.fromInt(CLayout.alignment layout),"_Alignof(" ^ name ^ ")")
              val members=case List.find(fn(n,_)=>n=name)fields of SOME(_,ms)=>ms | NONE=>[]
          in List.app(fn member=>
            let val ()=if valid member then () else raise Fail "invalid fixture field"
                val {offset,...}=CLayout.member(layout,String.fields(fn c=>c= #".")member)
            in emit(name ^ "." ^ member,offset,"offsetof(" ^ name ^ "," ^ member ^ ")") end)members end
        val ()=List.app one names
        val ()=List.app(fn(i,(label,expression))=>
          let val probe="runeffi_constant_" ^ Int.toString i
              val tokens=case List.find(fn CParse.Declaration{name=SOME n,...}=>n=probe | _=>false)declarations of
                SOME(CParse.Declaration{initializer,...})=>initializer | _=>raise Fail("missing " ^ probe)
              val value=CAnalysis.expression environment tokens
              val number=IntInf.mod(#integer value,IntInf.<<(1,0w64))
          in emit(label,number,expression) end)(mapi(fn p=>p)probes)
        val ()=write(output ^ ".expected",String.concat(rev(!expected)))
        val ()=write(output ^ ".c",includes ^ "#include <stddef.h>\n#include <stdio.h>\nint main(void){\n" ^
          String.concat(rev(!native)) ^ "return 0;\n}\n")
    in print("PASS SML header analysis: " ^ #name profile ^ ": " ^ Int.toString(length names) ^ " types, " ^
      Int.toString(length(!expected)) ^ " measured facts and constants\n") end
    | main _=raise Fail "expected PROFILE INVENTORY OUTPUT INCLUDE..."
  fun diagnostic({file,line,column}:CLex.location,text)=file ^ ":" ^ Int.toString line ^ ":" ^ Int.toString column ^ ": " ^ text
  fun error e=case e of CAnalysis.Error p=>diagnostic p | CLayout.Error p=>diagnostic p | CLayout.Shim p=>diagnostic p
    | CExpression.Error p=>diagnostic p | CParse.Error p=>diagnostic p | CPreprocess.Error p=>diagnostic p | _=>General.exnMessage e
end
val ()=HeaderLayout.main(CommandLine.arguments())handle e=>(TextIO.output(TextIO.stdErr,HeaderLayout.error e ^ "\n");OS.Process.exit OS.Process.failure)
