structure FfiProvisionTests =
struct
  open BuildCommon
  val count=ref 0
  fun check name condition=(need(condition,"provision fixture: " ^ name);count:= !count+1)
  fun refuses name action=check name ((action();false) handle Failed _=>true | OS.SysErr _=>true)
  fun member name kind link : BuildArchive.member={name=name,kind=kind,link=link,data=""}
  fun run ()=
    let val top="libffi-3.4.6"
        val ()=List.app(fn name=>refuses("archive path " ^ name)(fn()=>BuildFFIDeps.admitted top(member name #"0" "")))
          ["/tmp/escape","libffi-3.4.6/../escape","libffi-3.4.6/a/../../escape","other/file","libffi-3.4.6/a\\escape"]
        val ()=List.app(fn link=>refuses("archive link " ^ link)(fn()=>BuildFFIDeps.admitted top(member(top ^ "/link")#"2" link)))
          ["/tmp/escape","../../escape","../other/file"]
        val ()=BuildFFIDeps.admitted top(member(top ^ "/directory/")#"5" "")
        val ()=BuildFFIDeps.admitted top(member(top ^ "/directory/link")#"2" "../LICENSE")
        val ()=check "safe directory and internal relative link" true
        val ()=refuses "special archive file" (fn()=>BuildFFIDeps.admitted top(member(top ^ "/device")#"3" ""))
        val directory=privateDirectory(fromRoot "tests/out/provision")"fixtures"
        val archive=directory ^ "/source.tar.gz" val ()=write(archive,"pinned fixture")
        val calls=ref 0
        fun command _ _=(calls:= !calls+1;raise Failed "fixture must not launch a command")
        val ()=check "offline verified cache" (BuildFFIDeps.download archive(hash archive)[]true command=NONE)
        val ()=refuses "corrupt cached archive" (fn()=>ignore(BuildFFIDeps.download archive(String.implode(List.tabulate(64,fn _=> #"0")))[]true command))
        val ()=refuses "offline missing archive" (fn()=>ignore(BuildFFIDeps.download(directory ^ "/missing") (hash archive)[]true command))
        val ()=check "cache checks perform no subprocess work" (!calls=0)
        val prefix=directory ^ "/prefix" val ()=mkdirs prefix val ()=write(prefix ^ "/marker","original")
        val ()=refuses "failed publication restores prefix" (fn()=>BuildFFIDeps.publish(directory ^ "/absent")prefix)
        val ()=check "old prefix survives failure" (read(prefix ^ "/marker")="original")
        val staged=directory ^ "/stage" val ()=mkdirs staged val ()=write(staged ^ "/marker","replacement")
        val ()=BuildFFIDeps.publish staged prefix
        val ()=check "successful publication replaces whole prefix" (read(prefix ^ "/marker")="replacement" andalso not(exists staged))
        val ()=remove directory
    in say("PASS FFI dependency model: " ^ Int.toString(!count) ^ " checks\n") end
end
val ()=(BuildIO.initialize();FfiProvisionTests.run())
