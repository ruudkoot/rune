functor BenchPrettyFn (D : BENCH_SUSPEND) =
struct
  datatype cnode = CNil | CAppend of cnode D.t * cnode D.t
    | CIndent of int D.t * cnode D.t | CNewline | CStr of char list | CCh of char
  type cseq = cnode D.t
  datatype rep = Rep of {seq : cseq, last : int D.t, empty : bool D.t, fits : bool D.t}
  type pretty = int -> bool -> rep D.t
  datatype textNode = TNil | TCons of char * textNode D.t
  type text = textNode D.t
  structure L = BenchLazy
  structure S = BenchStream
  val cNil = D.delay (fn () => CNil)
  val cNL = D.delay (fn () => CNewline)
  fun cAppend a b = D.delay (fn () => CAppend (a,b))
  fun cIndent n seq = D.delay (fn () => CIndent (n,seq))
  fun cStr s = D.delay (fn () => CStr s)
  fun cCh c = D.delay (fn () => CCh c)
  fun later f = D.delay (fn () => D.force (f ()))
  fun seq r = later (fn () => case D.force r of Rep {seq,...} => seq)
  fun last r = case D.force r of Rep {last,...} => D.force last
  fun empty r = case D.force r of Rep {empty,...} => D.force empty
  fun fits r = case D.force r of Rep {fits,...} => D.force fits
  fun nilDoc width vertical = D.delay (fn () => Rep {seq=cNil,last=D.delay(fn()=>0),
    empty=D.delay(fn()=>true),fits=D.delay(fn()=>width>=0)})
  fun str chars width vertical = D.delay (fn () =>
    let val length = D.delay (fn () => List.length chars)
    in Rep {seq=cStr chars,last=length,empty=D.delay(fn()=>false),fits=D.delay(fn()=>width>=D.force length)} end)
  fun char c width vertical = D.delay (fn () => Rep {seq=cCh c,last=D.delay(fn()=>1),
    empty=D.delay(fn()=>false),fits=D.delay(fn()=>width>=1)})
  fun ofString s = str (String.explode s)
  fun int n =
    let val s = Int.toString n
        val s = if String.size s>0 andalso String.sub(s,0)= #"~" then "-"^String.substring(s,1,String.size s-1) else s
    in ofString s end
  fun beside p1 p2 width vertical = D.delay (fn () =>
    let val r1 = later (fn()=>p1 width false)
        val r2 = later (fn()=>p2 (width-last r1) false)
    in Rep {seq=later(fn()=>cAppend(seq r1)(cIndent(D.delay(fn()=>last r1))(seq r2))),
      last=D.delay(fn()=>last r1+last r2),empty=D.delay(fn()=>empty r1 andalso empty r2),
      fits=D.delay(fn()=>width>=0 andalso fits r1 andalso fits r2)} end)
  fun besideSP p1 p2 width vertical = D.delay (fn () =>
    let val r1 = later(fn()=>p1 width false)
        val li = D.delay(fn()=>if empty r1 then 0 else last r1+1)
        val wi = D.delay(fn()=>if empty r1 then 0 else 1)
        val r2 = later(fn()=>p2 (width-D.force li) false)
        val sp = later(fn()=>if empty r1 orelse empty r2 then cNil else cCh #" ")
    in Rep {seq=later(fn()=>cAppend(seq r1)(cAppend sp (cIndent li (seq r2)))),
      last=D.delay(fn()=>D.force li+last r2),empty=D.delay(fn()=>empty r1 andalso empty r2),
      fits=D.delay(fn()=>width>=D.force wi andalso fits r1 andalso fits r2)} end)
  fun above p1 p2 width vertical = D.delay (fn () =>
    let val r1 = later(fn()=>p1 width true) val r2 = later(fn()=>p2 width true)
        val nl = later(fn()=>if empty r1 orelse empty r2 then cNil else cNL)
    in Rep {seq=later(fn()=>cAppend(seq r1)(cAppend nl (seq r2))),last=D.delay(fn()=>last r2),
      empty=D.delay(fn()=>empty r1 andalso empty r2),fits=D.delay(fn()=>false)} end)
  fun nest n p width false = p width false
    | nest n p width true = D.delay(fn()=>
        let val r = later(fn()=>p (width-n) true)
        in Rep {seq=later(fn()=>cIndent(D.delay(fn()=>n))(seq r)),last=D.delay(fn()=>last r+n),
          empty=D.delay(fn()=>empty r),fits=D.delay(fn()=>fits r)} end)
  fun hang p1 n p2 width vertical = D.delay(fn()=>
    let val r1 = later(fn()=>p1 width false)
        val r2 = later(fn()=>p2 (width-(last r1+1)) false)
        val r3 = later(fn()=>p2 (width-n) false)
    in if empty r1 then D.force(p2 width vertical)
       else if last r1<=n orelse fits r2 then
         Rep {seq=later(fn()=>cAppend(seq r1)(cAppend(cCh #" ")(cIndent(D.delay(fn()=>last r1+1))(seq r2)))),
           last=D.delay(fn()=>last r1+1+last r2),empty=D.delay(fn()=>false),fits=D.delay(fn()=>fits r1 andalso fits r2)}
       else Rep {seq=later(fn()=>cAppend(seq r1)(cAppend cNL (cIndent(D.delay(fn()=>n))(seq r3)))),
         last=D.delay(fn()=>last r3),empty=D.delay(fn()=>false),fits=D.delay(fn()=>false)} end)
  fun foldDocs combine docs width vertical = D.delay(fn()=>case L.force docs of S.Nil => D.force(nilDoc width vertical)
    | S.Cons (p,rest) => case L.force rest of S.Nil => D.force((L.force p) width vertical)
      | _ => D.force(combine (L.force p) (foldDocs combine rest) width vertical))
  fun besides docs = foldDocs beside docs
  fun cat docs = foldDocs besideSP docs
  fun aboves docs = foldDocs above docs
  fun sep docs width vertical = D.delay(fn()=>case L.force docs of S.Nil => D.force(nilDoc width vertical)
    | S.Cons(p,rest) => case L.force rest of S.Nil => D.force((L.force p) width vertical)
      | _ => let val r=later(fn()=>cat docs width vertical)
             in if fits r then D.force r else D.force(aboves docs width vertical) end)
  fun take 0 _ = S.empty()
    | take n xs = L.delay(fn()=>case L.force xs of S.Nil=>S.Nil | S.Cons(x,rest)=>S.Cons(x,take(n-1)rest))
  fun chars [] tail = tail
    | chars(c::rest) tail = D.delay(fn()=>TCons(c,chars rest tail))
  fun indent n tail = D.delay(fn()=>
    let val amount=D.force n
    in if amount=0 then D.force tail
       else if amount>=8 then TCons(#"\t",indent(D.delay(fn()=>amount-8))tail)
       else TCons(#" ",indent(D.delay(fn()=>amount-1))tail) end)
  fun flatten n newline current stack = D.delay(fn()=>case D.force current of
      CNil=>D.force(flattenStack newline stack)
    | CAppend(a,b)=>D.force(flatten n newline a ((n,b)::stack))
    | CIndent(amount,rest)=>D.force(flatten(D.delay(fn()=>D.force amount+D.force n))newline rest stack)
    | CNewline=>TCons(#"\n",flattenStack true stack)
    | CStr s=>D.force(if newline then indent n (chars s (flattenStack false stack)) else chars s (flattenStack false stack))
    | CCh c=>D.force(if newline then indent n (chars[c](flattenStack false stack)) else chars[c](flattenStack false stack)))
  and flattenStack newline [] = D.delay(fn()=>TNil)
    | flattenStack newline ((column,rest)::stack) = flatten column newline rest stack
  fun show width p = flatten(D.delay(fn()=>0))true(seq(p width false))[]
  fun append a b = D.delay(fn()=>case D.force a of TNil=>D.force b | TCons(c,rest)=>TCons(c,append rest b))
  fun app emit text = case D.force text of TNil=>() | TCons(c,rest)=>(emit c;app emit rest)
  fun make words =
    let val word=ofString "xxxxx"
        val repeated=S.fix(fn root=>S.Cons(L.delay(fn()=>word),root))
        val first=besides(S.fromList[int (~42),char #"@",ofString "This is a string"])
        val last=hang(ofString "This is the label")8(cat(take words repeated))
    in aboves(S.fromList[first,ofString ", ",last])end
  fun run width words emit = app emit (append(show width(make words))(chars[#"\n"](D.delay(fn()=>TNil))))
end
