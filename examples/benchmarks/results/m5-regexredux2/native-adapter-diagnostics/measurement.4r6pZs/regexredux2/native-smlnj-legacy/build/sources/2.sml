(* Portable matcher for the precise Str fragment used by regexredux2.
   Alternatives are ordered; repetition is greedy; forward search is leftmost. *)
structure BenchRegexReduxStr =
struct
  datatype atom=Literal of char|Class of bool*char list|Any|Start|Finish|Repeat of atom
  type regexp=atom list list
  fun compile pattern=
    let val n=String.size pattern
        fun character i=String.sub(pattern,i)
        fun collect i negate chars=if i>=n then raise Fail "unterminated regex class"
          else if character i= #"]"then(Class(negate,rev chars),i+1)
          else collect(i+1)negate(character i::chars)
        fun parse i current alternatives=if i=n then rev(rev current::alternatives)
          else if i+1<n andalso character i= #"\\"andalso character(i+1)= #"|"
            then parse(i+2)[](rev current::alternatives)
          else if character i= #"*"then(case current of []=>raise Fail "regex repeat without atom"
              |a::rest=>parse(i+1)(Repeat a::rest)alternatives)
          else let val(a,next)=case character i of
                    #"["=>if i+1<n andalso character(i+1)= #"^"then collect(i+2)true[]else collect(i+1)false[]
                   | #"."=>(Any,i+1)| #"^"=>(Start,i+1)| #"$"=>(Finish,i+1)
                   | #"\\"=>if i+1<n then(Literal(character(i+1)),i+2)else raise Fail "trailing regex escape"
                   |c=>(Literal c,i+1)
            in parse next(a::current)alternatives end
    in parse 0[][]end
  fun matchesChar fold atom c=
    let fun equal a b=if fold then Char.toLower a=Char.toLower b else a=b
    in case atom of Literal a=>equal a c
      |Class(negate,chars)=>List.exists(fn a=>equal a c)chars<>negate
      |Any=>c<> #"\n"|_=>raise Fail "regex repetition of anchor"end
  fun match fold regex text start=
    let val n=String.size text
        fun one [] index=SOME index
          |one(Start::rest)index=if index=0 orelse String.sub(text,index-1)= #"\n"then one rest index else NONE
          |one(Finish::rest)index=if index=n orelse String.sub(text,index)= #"\n"then one rest index else NONE
          |one(Repeat atom::rest)index=
            let fun longest i=if i<n andalso matchesChar fold atom(String.sub(text,i))then longest(i+1)else i
                fun backtrack i=case one rest i of SOME answer=>SOME answer
                  |NONE=>if i=index then NONE else backtrack(i-1)
            in backtrack(longest index)end
          |one(atom::rest)index=if index<n andalso matchesChar fold atom(String.sub(text,index))
              then one rest(index+1)else NONE
        fun alternatives []=NONE|alternatives(first::rest)=case one first start of NONE=>alternatives rest|some=>some
    in if start<0 orelse start>n then raise Subscript else alternatives regex end
  fun search fold regex text start=
    let val n=String.size text
        fun loop index=if index>n then NONE else case match fold regex text index of
          NONE=>loop(index+1)|SOME finish=>SOME(index,finish)
    in if start<0 then raise Subscript else loop start end
  fun count regex text=
    let fun loop index total=case search true regex text index of NONE=>total
          |SOME(start,_)=>loop(start+1)(total+1)
    in loop 0 0 end
  fun replace regex replacement text=
    let val n=String.size text
        fun loop start chunks=case search false regex text start of
             NONE=>String.concat(rev(String.substring(text,start,n-start)::chunks))
           |SOME(first,finish)=>if first=finish then raise Fail "empty regex substitution unsupported"
             else loop finish(replacement::String.substring(text,start,first-start)::chunks)
    in loop 0[]end
end
