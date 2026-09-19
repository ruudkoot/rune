(* Posix.Signal: the signals, as the numbers the system gives them. *)
structure RunePosixSignal =
struct
  type signal = int

  local
    val const = _prim "posix_const" : string -> int
    fun named name = case const name of ~1 => 0 | v => v
  in
    fun toWord (s : signal) = Word.fromInt s
    fun fromWord w = Word.toInt w

    val abrt = named "SIGABRT"   val alrm = named "SIGALRM"
    val bus = named "SIGBUS"     val chld = named "SIGCHLD"
    val cont = named "SIGCONT"   val fpe = named "SIGFPE"
    val hup = named "SIGHUP"     val ill = named "SIGILL"
    val int = named "SIGINT"     val kill = named "SIGKILL"
    val pipe = named "SIGPIPE"   val quit = named "SIGQUIT"
    val segv = named "SIGSEGV"   val stop = named "SIGSTOP"
    val term = named "SIGTERM"   val tstp = named "SIGTSTP"
    val ttin = named "SIGTTIN"   val ttou = named "SIGTTOU"
    val usr1 = named "SIGUSR1"   val usr2 = named "SIGUSR2"
  end
end
