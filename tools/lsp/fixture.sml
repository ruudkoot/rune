(* A synthetic tree of SML libraries and programs, shaped by distributions
   measured on Rune, MLton and HOL4 (E20's gen.py, which this replaces), for
   the language server's scale target (D28; docs/language-server.md, The
   scale target).

   Usage: rune-lsp-fixture --out DIR --lines N --files F --builds B
            [--libraries L] [--seed S] [--functors P] [--sig-files P]
            [--sig-lines P] [--nested-sigs P] [--domains K] [--fan-mu M]
            [--no-text]

   Layout:
     libs/gNNN/lMMMMM/library.build  a library: a use of each library it is
                                     written on, then its files, in order
     libs/gNNN/lMMMMM/mM_I.sml       a module: a structure, or a functor and
                                     its application; mM_I.sig its signature
     apps/pKKKKK.build, .sml         a program: a use of some libraries, one file
     apps/all.build, all.sml         a use of every library: the whole tree
     fixture.json                    the parameters, and what came out

   The shape (log-normal fits of E20's shape.py): a file's lines, sigma 1.46,
   the mean from --lines over --files; a structure's fan-out, log mean
   --fan-mu (2.1 gives about 6 over all files, as measured), sigma 0.95;
   fan-in by preferential attachment; signature files --sig-files of the
   files (0.30) and --sig-lines of the lines (0.12); functor files
   --functors (0.10); files a library, sigma 1.35; a library's fan-out, log
   mean 1.2, sigma 0.7; 80% of the builds libraries unless --libraries says.
   --domains K puts the libraries in K domains, each written on itself and
   the first alone, so that a program's closure is about 1/K of the tree:
   with 32 at 10M lines, about 1M lines, D28's context. --nested-sigs P has
   that share of signatures specify their dependencies as structures, as
   MLton's do. --no-text writes the build files alone, for planning.

   The text is templates whose per-line costs were calibrated against real
   code (E20). The numbers are SplitMix64's (lib/random), so a seed gives the
   same tree on every host; they are not gen.py's, whose trees differ. *)
structure RuneLspFixture =
struct
  structure R=Random
  fun num n=Int.toString n
  fun pad (width,n)=StringCvt.padLeft #"0" width (num n)
  (* the generator, drawn from in one order *)
  val gen=ref (R.fromSeed 0w1)
  fun uniform ()=let val (x,g)=R.real (!gen) in gen:=g;x end
  fun below n=let val (x,g)=R.below (Word64.fromInt n) (!gen) in gen:=g;Word64.toInt x end
  fun range (lo,hi)=lo+below (hi-lo)
  fun gauss (mu,sigma)=
    let val u=1.0-uniform () val v=uniform ()
    in mu+sigma*Math.sqrt (~2.0*Math.ln u)*Math.cos (2.0*Math.pi*v) end
  fun lognorm (mean,sigma)=Math.exp (gauss (Math.ln mean-sigma*sigma/2.0,sigma))
  fun expovariate rate= ~(Math.ln (1.0-uniform ()))/rate
  fun round x=Real.round x
  fun trunc x=Real.trunc x
  (* a list that grows at its end, drawn from uniformly *)
  type 'a bag={items:'a array ref,count:int ref}
  fun bag ()={items=ref (Array.fromList []),count=ref 0}
  fun push ({items,count}:'a bag,x)=
    (if !count<Array.length (!items) then () else
       let val old= !items
       in items:=Array.tabulate (Int.max (16,2*Array.length old),fn i => if i<Array.length old then Array.sub (old,i) else x) end;
     Array.update (!items,!count,x);count:= !count+1)
  fun bagSize ({count,...}:'a bag)= !count
  fun pick ({items,count}:'a bag)=Array.sub (!items,below (!count))
  fun choice xs=List.nth (xs,below (length xs))
  (* a stable sort: of two equal, the earlier first *)
  fun insert less (x,[])=[x] | insert less (x,y::rest)=if less (y,x) then y::insert less (x,rest) else x::y::rest
  fun sortBy less xs=List.foldr (fn (x,sorted) => insert less (x,sorted)) [] xs
  (* the distinct numbers below n among xs, in order *)
  fun distinct (n,xs)=
    let val seen=Array.array (n,false)
        val ()=List.app (fn x => Array.update (seen,x,true)) xs
    in Array.foldri (fn (i,true,all) => i::all | (_,false,all) => all) [] seen end
  (* deps: the modules a module uses, by their place among all of them *)
  type module={id:int,lib:int,idx:int,name:string,lines:int ref,hasSig:bool,sigLines:int,opaque:bool,functor':bool,
               fanin:int ref,deps:int list ref}
  val types=["A of int","B of string * t","C of {x : int, y : t list}","D","E of int * int * t","F of string list"]
  val comments=["what a client of this module asks for most often, kept apart from the rest of it",
    "the value of a name at the point of use, where an earlier declaration may have shadowed it",
    "one step of the fold, with the accumulator first, as the callers of this function expect",
    "a total function: every constructor of t has its case here, and the default is never taken",
    "the result of a lookup that may fail: the caller decides what an absent entry should mean",
    "normalise before the comparison, so that two spellings of one value are treated as equal"]
  fun callExpr (d,x)=
    case below 4 of
      0 => d ^ ".size (" ^ d ^ ".make " ^ x ^ ")"
    | 1 => "String.size (" ^ d ^ ".show (" ^ d ^ ".make " ^ x ^ "))"
    | 2 => d ^ ".size (" ^ d ^ ".make (" ^ x ^ " + 1))"
    | _ => d ^ ".size (" ^ d ^ ".twice (" ^ d ^ ".make " ^ x ^ "))"
  (* a module's body, a declaration at a time, and its specification *)
  type body={deps:string list ref,fi:int ref,ints:string list ref,out:string list ref,spec:string list ref}
  fun intcall (b:body,x)=
    let val r=uniform ()
    in if not (null (!(#deps b))) andalso r<0.55 then callExpr (choice (!(#deps b)),x)
       else if not (null (!(#ints b))) andalso r<0.85 then choice (!(#ints b)) ^ " (" ^ x ^ ")"
       else let val a=range (2,9) val c=range (1,99) in "(" ^ x ^ ") * " ^ num a ^ " + " ^ num c end end
  fun emit (b:body)=
    let val t=below 9
        val ()= #fi b:= !(#fi b)+1
        val f="f" ^ num (!(#fi b))
        fun out lines= #out b:= List.revAppend (lines,!(#out b))
        fun spec lines= #spec b:= !(#spec b) @ lines
        val ()=if uniform ()<0.55 then out ["  (* " ^ f ^ ": " ^ choice comments ^ " *)"] else ()
    in case t of
         0 => let val a=range (2,9) val c=range (1,50) val b1=intcall (b,"a") val d=below 100
                  val e=range (50,500) val g=range (3,97) val h=intcall (b,"a")
              in out ["  fun " ^ f ^ " (x : int) : int =","    let","      val a = x * " ^ num a ^ " + " ^ num c,
                   "      val b = " ^ b1,"      val c = List.foldl (fn (y, acc) => y + acc) b [a, x, " ^ num d ^ "]",
                   "    in","      if c > " ^ num e ^ " then c mod " ^ num g ^ " else c + " ^ h,"    end"];
                 spec ["  val " ^ f ^ " : int -> int"]; #ints b:= !(#ints b) @ [f] end
       | 1 => let val a=below 9 val d=below 100
              in out ["  fun " ^ f ^ " (v : t) : int =","    case v of","      A n => n + " ^ num a,
                   "    | B (s, rest) => String.size s + " ^ f ^ " rest","    | C {x, y} => List.foldl (fn (e, acc) => acc + " ^ f ^ " e) x y",
                   "    | D => " ^ num d,"    | E (a, b, rest) => a * b + " ^ f ^ " rest",
                   "    | F names => List.foldl (fn (s, acc) => acc + String.size s) 0 names"];
                 spec ["  val " ^ f ^ " : t -> int"] end
       | 2 => let val c=intcall (b,"x") val d=below 999
              in out ["  fun " ^ f ^ " (x : int, sep : string) : string =","    let",
                   "      val parts = List.map Int.toString [x, x + 1, " ^ c ^ "]",
                   "      val tail = if x < 0 then \"negative\" else \"value " ^ num d ^ "\"","    in",
                   "      String.concatWith sep (tail :: parts)","    end"];
                 spec ["  val " ^ f ^ " : int * string -> string"] end
       | 3 => let val d=below 99 val c=intcall (b,"i")
                  val r=f ^ "_r"
              in out ["  type " ^ r ^ " = {name : string, count : int, items : int list}",
                   "  fun " ^ f ^ " ({name, count, items} : " ^ r ^ ") : " ^ r ^ " =",
                   "    {name = name ^ \"" ^ num d ^ "\", count = count + length items,",
                   "     items = List.rev (List.map (fn i => " ^ c ^ ") items)}"];
                 spec ["  type " ^ r ^ " = {name : string, count : int, items : int list}","  val " ^ f ^ " : " ^ r ^ " -> " ^ r] end
       | 4 => let val d=below 9 val c=intcall (b,"x")
              in out ["  exception " ^ f ^ "_error of string","  fun " ^ f ^ " (x : int) : int =","    let",
                   "      fun check n = if n < " ^ num d ^ " then raise " ^ f ^ "_error \"too small\" else n",
                   "    in","      check (" ^ c ^ ") handle " ^ f ^ "_error message => String.size message","    end"];
                 spec ["  exception " ^ f ^ "_error of string","  val " ^ f ^ " : int -> int"]; #ints b:= !(#ints b) @ [f] end
       | 5 => (out ["  fun " ^ f ^ " (g : 'a -> int) (xs : 'a list) : int option =","    case xs of","      [] => NONE",
                 "    | first :: rest =>","        SOME (List.foldl (fn (y, acc) => Int.max (g y, acc)) (g first) rest)"];
               spec ["  val " ^ f ^ " : ('a -> int) -> 'a list -> int option"])
       | 6 => let val c=intcall (b,"x")
              in out ["  fun " ^ f ^ " (x : int) : t =","    if x <= 0 then D","    else if x mod 2 = 0 then A (" ^ c ^ ")",
                   "    else if x mod 3 = 0 then E (x, x + 1, " ^ f ^ " (x - 3))","    else B (Int.toString x, " ^ f ^ " (x - 1))"];
                 spec ["  val " ^ f ^ " : int -> t"] end
       | 7 => let val a=range (1,5) val c=range (5,50) val d=below 9 val e=intcall (b,"r")
              in out ["  local","    fun helper (n, acc) = if n <= 0 then acc else helper (n - " ^ num a ^ ", acc + n)","  in",
                   "    fun " ^ f ^ " (x : int) : int * bool =","      let val r = helper (x mod " ^ num c ^ ", " ^ num d ^ ")",
                   "      in (r, r mod 2 = 0 orelse " ^ e ^ " > 0) end","  end"];
                 spec ["  val " ^ f ^ " : int -> int * bool"] end
       | _ => let val a=range (2,7) val c=intcall (b,"v")
              in out ["  fun " ^ f ^ " (xs : int list) : int list =","    let",
                   "      val kept = List.filter (fn v => v mod " ^ num a ^ " <> 0) xs",
                   "      val doubled = List.map (fn v => " ^ c ^ ") kept","    in","      List.rev doubled @ [length xs]","    end"];
                 spec ["  val " ^ f ^ " : int list -> int list"] end end
  val base=["  datatype t = " ^ String.concatWith "\n    | " types,
    "  fun make (n : int) : t = if n <= 0 then D else if n mod 2 = 0 then A n else B (Int.toString n, D)",
    "  fun size (v : t) : int =","    case v of","      A n => n","    | B (s, _) => String.size s","    | C {x, ...} => x","    | D => 0",
    "    | E (a, b, _) => a + b","    | F xs => length xs","  fun show (v : t) : string = Int.toString (size v)","  fun twice (v : t) : t = E (size v, size v, v)"]
  val baseLines=List.foldl (fn (line,n) => n+1+CharVector.foldl (fn (c,k) => if c= #"\n" then k+1 else k) 0 line) 0 base
  val baseSig=["  type t","  val make : int -> t","  val size : t -> int","  val show : t -> string","  val twice : t -> t"]
  val baseSigT=("  datatype t = " ^ String.concatWith "\n    | " types)::tl baseSig
  val param="sig type t val make : int -> t val size : t -> int val show : t -> string val twice : t -> t end"
  fun header (name,lib)="(* generated by tools/lsp/fixture.sml: module " ^ name ^ " of library " ^ num lib ^ " *)"
  fun upper s=String.map Char.toUpper s
  fun mkdirs dir=if dir="" orelse (OS.FileSys.isDir dir handle OS.SysErr _ => false) then ()
    else (mkdirs (OS.Path.dir dir);OS.FileSys.mkDir dir handle OS.SysErr _ => ())
  fun main arguments=
    let val out=ref "" val lines=ref 0 val files=ref 0 val builds=ref 0 val libraries=ref 0 val seed=ref 1
        val functors=ref 0.10 val sigFiles=ref 0.30 val sigLines=ref 0.12 val nested=ref 0.0 val domains=ref 0
        val fanMu=ref 2.1 val noText=ref false
        fun int value=valOf (Int.fromString value) fun realOf value=valOf (Real.fromString value)
        fun options []=()
          | options ("--out"::v::rest)=(out:=v;options rest)
          | options ("--lines"::v::rest)=(lines:=int v;options rest)
          | options ("--files"::v::rest)=(files:=int v;options rest)
          | options ("--builds"::v::rest)=(builds:=int v;options rest)
          | options ("--libraries"::v::rest)=(libraries:=int v;options rest)
          | options ("--seed"::v::rest)=(seed:=int v;options rest)
          | options ("--functors"::v::rest)=(functors:=realOf v;options rest)
          | options ("--sig-files"::v::rest)=(sigFiles:=realOf v;options rest)
          | options ("--sig-lines"::v::rest)=(sigLines:=realOf v;options rest)
          | options ("--nested-sigs"::v::rest)=(nested:=realOf v;options rest)
          | options ("--domains"::v::rest)=(domains:=int v;options rest)
          | options ("--fan-mu"::v::rest)=(fanMu:=realOf v;options rest)
          | options ("--no-text"::rest)=(noText:=true;options rest)
          | options (other::_)=raise Fail ("unknown option: " ^ other)
        val ()=options arguments
        val ()=if !out="" orelse !lines<1 orelse !files<1 orelse !builds<1 then raise Fail "--out, --lines, --files and --builds are required" else ()
        val ()=if !sigFiles>0.0 andalso !sigFiles<1.0 andalso !sigLines>0.0 andalso !sigLines<1.0 then ()
          else raise Fail "--sig-files and --sig-lines lie between 0 and 1"
        val ()=gen:=R.fromSeed (Word64.fromInt (!seed))
        (* libraries and their sizes *)
        val B=Int.max (2,!builds)
        val L=if !libraries>0 then !libraries else Int.max (1,trunc (real B*0.8))
        val P=Int.max (1,B-L)
        val drawn=List.tabulate (L,fn _ => Real.max (2.0,lognorm (real (!files)/real L,1.35)))
        val scale=real (!files)/List.foldl op+ 0.0 drawn
        val sizes=Vector.fromList (List.map (fn s => Int.max (2,round (s*scale))) drawn)
        fun libdir i="libs/g" ^ pad (3,i div 30) ^ "/l" ^ pad (5,i)
        fun domain i=if !domains>0 then i* !domains div L else 0
        (* what each library is written on: a DAG in index order, preferential on
           fan-in, near neighbours favoured so that depth grows *)
        val urn=bag () : int bag
        val libdeps=Array.array (L,[]) : int list array
        val ()=Array.appi (fn (i,_) =>
          let val k=Int.min (i,round (Math.exp (gauss (1.2,0.7))))
              val chosen=ref [] val tries=ref 0
              val ()=while length (!chosen)<k andalso !tries<k*8 do
                (tries:= !tries+1;
                 let val c=if bagSize urn>0 andalso uniform ()<0.5 then pick urn
                       else Int.max (0,i-1-trunc (expovariate (1.0/Real.max (1.0,real (Int.min (i,12))))))
                 in if !domains>0 andalso domain c<>0 andalso domain c<>domain i then ()
                    else if c<i andalso not (List.exists (fn x => x=c) (!chosen)) then chosen:=c:: !chosen else () end)
              val sorted=distinct (L,!chosen)
          in Array.update (libdeps,i,sorted);List.app (fn c => push (urn,c)) sorted;push (urn,i) end) libdeps
        val depth=Array.array (L,0)
        val ()=Array.appi (fn (i,deps) => Array.update (depth,i,1+List.foldl (fn (j,m) => Int.max (m,Array.sub (depth,j))) 0 deps)) libdeps
        (* modules *)
        val pSig= !sigFiles/(1.0- !sigFiles)
        val meanM=real (!lines)/real (!files)
        val s= !sigFiles
        val ratio=(!sigLines/(1.0- !sigLines))*((1.0-s)/s)
        val mStruct=meanM/(s*ratio+(1.0-s))
        val mSig=Real.max (4.0,ratio*mStruct)
        val perlib=Array.array (L,[]) : module list array
        val serial=ref 0
        val ()=Array.appi (fn (li,_) =>
          let val n=Vector.sub (sizes,li)
              fun loop (made,idx,mods)=if made>=n then List.rev mods else
                let val lines'=Int.max (6,trunc (lognorm (mStruct,1.46)))
                    val hasSig=uniform ()<pSig andalso made+1<n
                    val sigLines'=if hasSig then Int.max (5,trunc (lognorm (mSig,1.2))) else 0
                    val opaque=hasSig andalso uniform ()<0.3
                    val functor'=uniform ()< !functors/(1.0- !sigFiles)
                    val m={id= !serial,lib=li,idx=idx,name="M" ^ num li ^ "_" ^ num idx,lines=ref lines',hasSig=hasSig,sigLines=sigLines',
                           opaque=opaque,functor'=functor',fanin=ref 0,deps=ref []}:module
                in serial:= !serial+1;loop (made+(if hasSig then 2 else 1),idx+1,m::mods) end
          in Array.update (perlib,li,loop (0,0,[])) end) perlib
        val mods=List.concat (Array.foldr op:: [] perlib)
        val byId=Vector.fromList mods
        fun depsOf (m:module)=List.map (fn i => Vector.sub (byId,i)) (!(#deps m))
        (* the sampled sizes, scaled to the lines asked for *)
        val structLines=List.foldl (fn (m:module,n) => n+ !(#lines m)) 0 mods
        val ()=List.app (fn m:module => #lines m:=Int.max (6,trunc (real (!(#lines m))*real (!lines)*(1.0- !sigLines)/real structLines))) mods
        val visible=Array.array (L,[]) : int list array
        val ()=Array.appi (fn (li,_) =>
          let val deps=Array.sub (libdeps,li)
          in Array.update (visible,li,distinct (L,deps @ List.concat (List.map (fn j => Array.sub (visible,j)) deps))) end) visible
        (* what each module uses: fan-out, preferential within what its library may see *)
        val modurn=Array.array (L,[]) : module list array
        val ()=Array.appi (fn (li,_) =>
          let val pool=bag () : module bag
              val ()=List.app (fn j => List.app (fn m => push (pool,m)) (List.drop (Array.sub (modurn,j),Int.max (0,length (Array.sub (modurn,j))-200))))
                (Array.sub (libdeps,li))
              val local'=bag () : module bag
              fun one (m:module)=
                let val k=round (Math.exp (gauss (!fanMu,0.95)))
                    val deps=ref [] : module list ref
                    fun draw n=if n=0 then () else
                      let val useLocal=bagSize local'>0 andalso (uniform ()<0.6 orelse bagSize pool=0)
                          val source=if useLocal then local' else pool
                      in if bagSize source=0 then () else
                           let val d=pick source
                           in if List.exists (fn (x:module) => #id x= #id d) (!deps) then draw (n-1)
                              else (deps:=d:: !deps; #fanin d:= !(#fanin d)+1;push (source,d);draw (n-1)) end end
                    val ()=draw (Int.max (0,Int.min (k,60)))
                in #deps m:=List.rev (List.map #id (!deps));push (local',m);push (local',m) end
              val ()=List.app one (Array.sub (perlib,li))
              val mine=Array.sub (perlib,li)
              val ranked=sortBy (fn (a:module,b:module) => !(#fanin a)> !(#fanin b)) mine
              val top=List.take (ranked,Int.min (length ranked,Int.max (4,length mine div 3)))
          in Array.update (modurn,li,List.concat (List.map (fn m => List.tabulate (1+Int.min (!(#fanin m),6),fn _ => m)) top)) end) modurn
        (* programs: they favour the libraries nothing else is written on *)
        val used=List.concat (Array.foldr op:: [] libdeps)
        val tops=case List.filter (fn i => not (List.exists (fn j => j=i) used)) (List.tabulate (L,fn i => i)) of [] => [L-1] | t => t
        val progs=List.tabulate (P,fn _ =>
          let val k=Int.max (1,round (Math.exp (gauss (1.2,0.7))))
              val chosen=List.tabulate (k,fn _ => choice tops)
              val chosen=if uniform ()<0.7 then below L::chosen else chosen
          in distinct (L,chosen) end)
        (* the text *)
        val count=ref 0 val total=ref 0 val bytes=ref 0
        fun write (path,text)=
          let val n=CharVector.foldl (fn (c,k) => if c= #"\n" then k+1 else k) 0 text
          in count:= !count+1;total:= !total+n;bytes:= !bytes+String.size text;
             if !noText andalso not (String.isSuffix ".build" path) then () else
             let val full=OS.Path.concat (!out,path)
                 val ()=mkdirs (OS.Path.dir full)
                 val output=TextIO.openOut full
             in TextIO.output (output,text);TextIO.closeOut output end end
        val ()=mkdirs (!out)
        fun library li=
          let val d=libdir li
              fun module (m:module)=
                let val deps=List.map #name (depsOf m)
                    val isFunctor= #functor' m andalso not (null deps)
                    val bodyDeps=if isFunctor then "A"::tl deps else deps
                    val b={deps=ref [],fi=ref 0,ints=ref [],out=ref [],spec=ref []}:body
                    val ()=List.app (fn x => (#deps b:=[x];emit b)) bodyDeps
                    val ()= #deps b:=bodyDeps
                    val ()=while length (!(#out b))+baseLines+6< !(#lines m) do emit b
                    val body=List.rev (!(#out b))
                    val stem="m" ^ num (#lib m) ^ "_" ^ num (#idx m)
                    val sigName=upper (#name m) ^ "_SIG"
                    val (entries,rebound)=if not (#hasSig m) then ([],[]) else
                      let val sg=(if #opaque m then baseSig else baseSigT) @ !(#spec b)
                          val (extra,rebound)=if uniform ()< !nested then
                            ListPair.unzip (List.mapPartial (fn (x:module) =>
                              if #hasSig x andalso #lib x<= #lib m andalso not isFunctor
                              then SOME ("  structure " ^ #name x ^ " : " ^ upper (#name x) ^ "_SIG","  structure " ^ #name x ^ " = " ^ #name x)
                              else NONE) (List.take (depsOf m,Int.min (6,length (!(#deps m))))))
                            else ([],[])
                      in write (d ^ "/" ^ stem ^ ".sig",header (#name m,li) ^ "\nsignature " ^ sigName ^ " =\nsig\n" ^
                           String.concatWith "\n" (extra @ sg) ^ "\nend\n");
                         ([stem ^ ".sig"],rebound) end
                    val ascription=if not (#hasSig m) then "" else (if #opaque m then " :> " else " : ") ^ sigName
                    val text=String.concatWith "\n" (rebound @ base @ body)
                    val () =if isFunctor then
                      write (d ^ "/" ^ stem ^ ".sml",header (#name m,li) ^ "\nfunctor " ^ #name m ^ "F (A : " ^ param ^ ") =\nstruct\n" ^ text ^
                        "\nend\nstructure " ^ #name m ^ ascription ^ " = " ^ #name m ^ "F (" ^ hd deps ^ ")\n")
                      else write (d ^ "/" ^ stem ^ ".sml",header (#name m,li) ^ "\nstructure " ^ #name m ^ ascription ^ " =\nstruct\n" ^ text ^ "\nend\n")
                in entries @ [stem ^ ".sml"] end
              val entries=List.concat (List.map module (Array.sub (perlib,li)))
              fun relative j="../../g" ^ pad (3,j div 30) ^ "/l" ^ pad (5,j) ^ "/library.build"
          in write (d ^ "/library.build","(* generated: library " ^ num li ^ " *)\n" ^
               String.concat (List.map (fn j => "use " ^ relative j ^ "\n") (Array.sub (libdeps,li))) ^
               "files\n" ^ String.concat (List.map (fn e => "  " ^ e ^ "\n") entries) ^ "end\n") end
        val ()=List.app library (List.tabulate (L,fn i => i))
        fun program (name,chosen)=
          let val picked=List.map (fn j => choice (Array.sub (perlib,j))) chosen
              val picked=List.take (picked,Int.min (64,length picked))
          in write ("apps/" ^ name ^ ".build","(* generated: program " ^ name ^ " *)\n" ^
               String.concat (List.map (fn j => "use ../libs/g" ^ pad (3,j div 30) ^ "/l" ^ pad (5,j) ^ "/library.build\n") chosen) ^
               "files\n  " ^ name ^ ".sml\nend\n");
             write ("apps/" ^ name ^ ".sml",String.concatWith "\n" (["val total = ref 0"] @
               ListPair.map (fn (m:module,i) => "val () = total := !total + " ^ #name m ^ ".size (" ^ #name m ^ ".make " ^ num (i+2) ^ ")")
                 (picked,List.tabulate (length picked,fn i => i)) @ ["val () = print (Int.toString (!total) ^ \"\\n\")"]) ^ "\n") end
        val ()=ListPair.app (fn (chosen,p) => program ("p" ^ pad (5,p),chosen)) (progs,List.tabulate (P,fn p => p))
        val ()=program ("all",List.tabulate (L,fn i => i))
        (* what came out *)
        fun files' li=Vector.sub (sizes,li)
        val closure=List.tabulate (L,fn i => files' i+List.foldl (fn (j,n) => n+files' j) 0 (Array.sub (visible,i)))
        val progClosure=List.map (fn chosen =>
          List.foldl (fn (j,n) => n+files' j) 0 (distinct (L,chosen @ List.concat (List.map (fn j => Array.sub (visible,j)) chosen)))) progs
        val sum=List.foldl op+ 0
        fun mean (total,n)=Json.Number (Real.fmt (StringCvt.FIX (SOME 2)) (real total/real (Int.max (1,n))))
        val nMods=length mods
        val info=Json.Object [("lines",Json.int (!lines)),("files",Json.int (!files)),("builds",Json.int (!builds)),
          ("seed",Json.int (!seed)),("domains",Json.int (!domains)),("no_text",Json.Bool (!noText)),
          ("libraries",Json.int L),("programs",Json.int P),("build_files",Json.int (L+P+1)),
          ("generated_files",Json.int (!count)),("generated_lines",Json.int (!total)),("generated_bytes",Json.int (!bytes)),
          ("library_depth",Json.int (Array.foldl Int.max 0 depth)),
          ("library_fan_out_mean",mean (sum (List.map length (Array.foldr op:: [] libdeps)),L)),
          ("modules",Json.int nMods),("max_module_fan_in",Json.int (List.foldl (fn (m:module,n) => Int.max (n,!(#fanin m))) 0 mods)),
          ("mean_module_fan_out",mean (sum (List.map (fn m:module => length (!(#deps m))) mods),nMods)),
          ("mean_visible_libraries",mean (sum (List.map length (Array.foldr op:: [] visible)),L)),
          ("mean_library_closure_files",mean (sum closure,L)),("mean_program_closure_files",mean (sum progClosure,length progClosure)),
          ("memberships_all_targets",Json.int (sum closure+sum progClosure+sum (Vector.foldr op:: [] sizes)))]
        val output=TextIO.openOut (OS.Path.concat (!out,"fixture.json"))
        val ()=(TextIO.output (output,Json.encode info ^ "\n");TextIO.closeOut output)
    in print (Json.encode info ^ "\n");OS.Process.success end
    handle Fail message => (TextIO.output (TextIO.stdErr,"rune-lsp-fixture: " ^ message ^ "\n");OS.Process.failure)
end
