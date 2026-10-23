(* Implements: FOREIGN_ADAPTER *)
structure ForeignAdapter : FOREIGN_ADAPTER =
struct
  type prepared={policy:ForeignPolicy.policy,declarations:CParse.declaration list}
  exception Error=ForeignModel.Error
  fun prepare {policy:ForeignPolicy.policy,declarations,macros} =
    let fun fail source message=raise Error(source,message)
        val index=ForeignModel.index(ForeignModel.fromC declarations)
        val typedefs=List.mapPartial(fn CParse.Declaration{name,storage,...}=>
          if List.exists(fn word=>word="typedef")storage then name else NONE | _=>NONE)declarations
        fun function ty=case ty of CParse.Attributed(base,_)=>function base | CParse.Function f=>SOME f | _=>NONE
        fun original name source=
          case List.find(fn CParse.Declaration{name=other,location,...}=>other=SOME name andalso location=source | _=>false)declarations of
            SOME(CParse.Declaration{ctype,...})=>ctype | _=>fail source("missing original adapter function: " ^ name)
        fun typeSyntax source ty=case ty of
            CParse.Builtin _=>() | CParse.Named _=>()
          | CParse.Pointer{target,...}=>typeSyntax source target
          | CParse.Array _=>fail source "shim prototypes use pointer parameters rather than array declarators"
          | CParse.Function{result,parameters,variadic,prototype}=>
              if variadic orelse not prototype then fail source "nested shim function types must have fixed prototypes" else
                (typeSyntax source result;List.app(fn CParse.Parameter{ctype,...}=>typeSyntax source ctype)parameters)
          | CParse.Record{kind,tag=SOME tag,fields=NONE,...}=>
              if isSome(ForeignModel.lookup(index,{family="c",namespace=case kind of CParse.Struct=>"struct" | CParse.Union=>"union",name=tag})) then ()
              else fail source "shim aggregate tag is absent from original headers"
          | CParse.Record _=>fail source "shim prototypes cannot define aggregate types"
          | CParse.Enum{tag=SOME tag,values=NONE}=>
              if isSome(ForeignModel.lookup(index,{family="c",namespace="enum",name=tag})) then () else fail source "shim enum tag is absent from original headers"
          | CParse.Enum _=>fail source "shim prototypes cannot define enum types"
          | CParse.Attributed(base,attributes)=>
              let val allowed=["const","volatile","restrict","__restrict","__restrict__","_Atomic",
                    "cdecl","__cdecl","stdcall","__stdcall","fastcall","__fastcall","ms_abi","sysv_abi","__attribute__","__attribute"]
                  val ()=List.app(fn tokens=>List.app(fn token:CLex.token=>if #kind token=CLex.Identifier andalso
                    not(List.exists(fn word=>word= #text token)allowed) then fail source "unsupported attribute in fixed shim prototype" else ())tokens)attributes
              in typeSyntax source base end
        fun prototype (p:ForeignPolicy.functionPolicy) text=
          let val parsed=(CParse.translationUnit{tokens=CLex.scan{file= #file(#source p),text=text ^ ";"},predefinedTypes=typedefs}
                handle CLex.Error(_,message)=>fail (#source p)("invalid shim prototype: " ^ message)
                  | CParse.Error(_,message)=>fail (#source p)("invalid shim prototype: " ^ message))
          in case #declarations parsed of
              [CParse.Declaration{name=SOME name,ctype,storage=[],initializer=[],body=[],...}]=>
                if name<> #foreign p then fail (#source p) "shim prototype name differs from selected foreign name" else
                  (case function ctype of SOME f=>if #prototype f andalso not(#variadic f) then (ctype,f)
                    else fail (#source p) "shim prototype must be fixed and fully prototyped"
                  | NONE=>fail (#source p) "shim annotation requires a function prototype")
            | _=>fail (#source p) "shim annotation permits exactly one function prototype without storage or a body"
          end
        fun fixedPolicy(p:ForeignPolicy.functionPolicy) : ForeignPolicy.functionPolicy =
          {foreign= #foreign p,namespace="function",name= #name p,raw= #raw p,parameters= #parameters p,result= #result p,
           errors= #errors p,variadic= #variadic p,unsafeRaw= #unsafeRaw p,adapter= #adapter p,shim= #shim p,
           input= #input p,returns= #returns p,source= #source p}
        fun adapt (p:ForeignPolicy.functionPolicy)=case #shim p of NONE=>
              if #namespace p="macro" then fail (#source p) "selected macro requires an explicit fixed shim prototype" else NONE
          | SOME text=>
            let val(ty,fixed)=prototype p text
                val ()=typeSyntax (#source p) ty
                val location=if #namespace p="macro" then
                    (case List.find(fn m:CPreprocess.macro=> #name m= #foreign p)macros of NONE=>fail (#source p) "shim macro is absent from original headers"
                     | SOME macro=>let val count=length(#parameters fixed)
                         val ()=case #parameters macro of NONE=>() | SOME parameters=>
                           if (if #variadic macro then count>=length parameters else count=length parameters) then ()
                           else fail (#source p) "shim prototype argument count differs from original macro"
                       in #location macro end)
                  else let val declaration=case ForeignModel.lookup(index,{family="c",namespace="function",name= #foreign p}) of
                            SOME d=>d | NONE=>fail (#source p) "shim function is absent from original headers"
                           val ty=original (#foreign p)(#source declaration)
                           val native=case function ty of SOME f=>f | NONE=>fail (#source p) "shim selection is not a C function"
                           fun same(a,b)=CDeclarator.declaration(a,"runeffi_value")=CDeclarator.declaration(b,"runeffi_value")
                           val ()=if #prototype native then () else fail (#source p) "original shim function must have a prototype"
                           val ()=if same(#result native,#result fixed) then () else fail (#source p) "shim result type differs from original declaration"
                           val count=length(#parameters native)
                           val ()=if (if #variadic native then length(#parameters fixed)>=count else length(#parameters fixed)=count) then ()
                             else fail (#source p) "shim prototype argument count differs from original function"
                           val prefix=List.take(#parameters fixed,count)
                           val ()=ListPair.app(fn(CParse.Parameter{ctype=a,...},CParse.Parameter{ctype=b,...})=>
                             if same(a,b) then () else fail (#source p) "shim fixed-prefix type differs from original declaration")(#parameters native,prefix)
                       in #source declaration end
                val declaration=CParse.Declaration{name=SOME(#foreign p),ctype=ty,storage=[],initializer=[],body=[],location=location}
            in SOME(p,declaration) end
        val replacements=List.mapPartial adapt (#functions policy)
        fun replaced name=List.exists(fn(p:ForeignPolicy.functionPolicy,_)=>name=SOME(#foreign p))replacements
        val updated=List.filter(fn CParse.Declaration{name,storage,...}=>
          List.exists(fn word=>word="typedef")storage orelse not(replaced name) | _=>true)declarations @ List.map #2 replacements
        val functions=List.map(fn p:ForeignPolicy.functionPolicy=>if isSome(#shim p) then fixedPolicy p else p)(#functions policy)
        val policy={version= #version policy,family= #family policy,structureName= #structureName policy,headers= #headers policy,
          libraries= #libraries policy,resources= #resources policy,functions=functions,callbacks= #callbacks policy,source= #source policy}
    in {policy=policy,declarations=updated} end
end
