(* Tolmach/Nordin CSP tree transformations, preserving delayed labels/children. *)
functor BenchConstraintsFn(D : BENCH_SUSPEND) =
struct
  structure Q = BenchCellSequenceFn(D)
  datatype 'a node = Node of 'a D.t * 'a node D.t Q.sequence
  type 'a tree = 'a node D.t
  type assignment = int * int
  type state = assignment list
  type csp = {variables : int, values : int, relation : assignment * assignment -> bool}
  datatype conflict = Unknown | Known of int Q.sequence
  type label = state * conflict D.t
  type table = conflict Q.sequence Q.sequence
  fun value x = Q.value x
  fun range low high = D.delay(fn () => if low>high then Q.Nil
    else Q.Cons(value low,range(low+1)high))
  fun filter predicate xs = D.delay(fn () => case D.force xs of Q.Nil => Q.Nil
    | Q.Cons(x,rest) => if predicate(D.force x) then Q.Cons(x,filter predicate rest)
        else D.force(filter predicate rest))
  fun concat xs = D.delay(fn () => case D.force xs of Q.Nil => Q.Nil
    | Q.Cons(x,rest) => D.force(Q.append(D.force x)(concat rest)))
  fun zipWith f xs ys = D.delay(fn () => case D.force xs of Q.Nil => Q.Nil
    | Q.Cons(x,xs') => case D.force ys of Q.Nil => Q.Nil
      | Q.Cons(y,ys') => Q.Cons(D.delay(fn () => f(D.force x,D.force y)),zipWith f xs' ys'))
  fun null xs = case D.force xs of Q.Nil => true | _ => false
  fun all predicate xs = case D.force xs of Q.Nil => true
    | Q.Cons(x,rest) => predicate(D.force x) andalso all predicate rest
  fun member x xs = case D.force xs of Q.Nil => false
    | Q.Cons(y,rest) => x=D.force y orelse member x rest
  fun nub xs =
    let fun loop seen xs = D.delay(fn () => case D.force xs of Q.Nil => Q.Nil
          | Q.Cons(x,rest) => let val y=D.force x
            in if List.exists(fn z => y=z)seen then D.force(loop seen rest)
               else Q.Cons(x,loop(y::seen)rest)end)
    in loop [] xs end
  fun union xs ys = Q.append xs (filter(fn y => not(member y xs))(nub ys))
  fun level [] = 0 | level ((variable,_)::_) = variable
  fun safe ((i,m),(j,n)) = m<>n andalso Int.abs(i-j)<>Int.abs(m-n)
  fun knownConflict Unknown = false | knownConflict(Known set) = not(null set)
  fun knownSolution Unknown = false | knownSolution(Known set) = null set
  fun queens size : csp = {variables=size,values=size,relation=safe}
  fun complete (problem : csp) state = if level state= #variables problem then Known(Q.empty()) else Unknown
  fun earliest (problem : csp) [] = NONE
    | earliest problem (first::rest) =
        let fun find [] = NONE
              | find(other::tail) = if #relation problem (first,other) then find tail else SOME(#1 first,#1 other)
        in find(List.rev rest)end
  fun label tree = let val Node(result,_) = D.force tree in D.force result end
  fun mapTree f tree = D.delay(fn () =>
    let val Node(result,children) = D.force tree
    in Node(D.delay(fn () => f(D.force result)),Q.map(mapTree f)children)end)
  fun foldTree f tree = D.delay(fn () =>
    let val Node(result,children) = D.force tree
    in f result (Q.map(foldTree f)children)end)
  fun filterTree predicate tree = foldTree
    (fn result => fn children => Node(result,filter(fn child => predicate(label child))children))tree
  fun prune predicate tree = filterTree(fn result => not(predicate result))tree
  fun leaves tree = D.delay(fn () =>
    let val Node(result,children) = D.force tree
    in if null children then Q.Cons(result,Q.empty())
       else D.force(concat(Q.map leaves children))end)
  fun initial (problem : csp) state = D.delay(fn () => Node(value state,
    D.delay(fn () => if level state>= #variables problem then Q.Nil else D.force
      (Q.map(fn candidate => initial problem ((level state+1,candidate)::state))(range 1 (#values problem))))))
  fun bt problem = mapTree(fn state => (state,D.delay(fn () =>
    case earliest problem state of NONE => complete problem state
    | SOME(a,b) => Known(Q.fromList[a,b]))))
  fun search transform problem =
    Q.map #1 (filter(fn (_,conflict) => knownSolution(D.force conflict))
      (leaves(prune(fn (_,conflict) => knownConflict(D.force conflict))
        (transform problem (initial problem [])))))
  fun emptyTable (problem : csp) = Q.cons(value(Q.empty()))
    (Q.map(fn _ => Q.replicate (#values problem)(value Unknown))(range 1 (#variables problem)))
  fun fillTable [] _ table = table
    | fillTable (current::_) (problem : csp) table =
        let val (variable',_) = current
            val positions = Q.map(fn variable => Q.map(fn candidate => (variable,candidate))
                  (range 1 (#values problem)))(range(variable'+1)(#variables problem))
            fun update (Unknown,assignment) =
                  if #relation problem (current,assignment) then Unknown
                  else Known(Q.fromList[variable',#1 assignment])
              | update (conflict,_) = conflict
        in zipWith (fn (row,positions) => zipWith update row positions)table positions end
  fun cacheChecks problem table tree = D.delay(fn () =>
    let val Node(state,children) = D.force tree
        val nextTable = D.delay(fn () => fillTable (D.force state) problem (Q.tail(D.force table)))
    in Node(D.delay(fn () => (D.force state,table)),Q.map(cacheChecks problem nextTable)children)end)
  fun lookupCache problem = mapTree(fn (state,table) =>
    ((state,D.delay(fn () => case state of [] => Unknown
      | (_,candidate)::_ =>
          let val row = Q.head(D.force table)
              fun nth xs 0 = Q.head xs | nth xs n = nth(Q.tail xs)(n-1)
          in case nth row (candidate-1) of Unknown => complete problem state | conflict => conflict end)),table))
  fun bm problem tree = mapTree #1 (lookupCache problem
    (cacheChecks problem (value(emptyTable problem))tree))
  fun combine labels accumulator = D.delay(fn () => case D.force labels of Q.Nil => D.force accumulator
    | Q.Cons(item,rest) =>
        let val (state,conflict) = D.force item
        in case D.force conflict of Unknown => raise Match
          | Known set => if not(member(level state)set) then D.force set
              else D.force(combine rest (union set accumulator))end)
  fun backjump drop tree = foldTree(fn original => fn children =>
    let val (state,conflict) = D.force original
    in case D.force conflict of
        Known _ => Node(original,children)
      | Unknown =>
          let val combined = Known(combine(Q.map label children)(Q.empty()))
              val survivors = if drop andalso knownConflict combined then Q.empty() else children
          in Node(value(state,value combined),survivors)end
    end)tree
  fun bjbt problem tree = backjump false (bt problem tree)
  fun bjbt' problem tree = backjump true (bt problem tree)
  fun collect conflicts = D.delay(fn () => case D.force conflicts of Q.Nil => Q.Nil
    | Q.Cons(item,rest) => case D.force item of Unknown => raise Match
      | Known set => D.force(union set (collect rest)))
  fun domainWipeOut tree = mapTree(fn ((state,conflict),table) =>
    (state,D.delay(fn () =>
      let val wiped = filter(all knownConflict)(D.force table)
      in if null wiped then D.force conflict else Known(collect(Q.head wiped))end))) tree
  fun fc problem tree = domainWipeOut(lookupCache problem
    (cacheChecks problem (value(emptyTable problem))tree))
end
