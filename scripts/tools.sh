# Shared POSIX shell tool discovery. Tool overrides are executable paths, not flags.
if [ -z "${SMLNJ_HOME:-}" ] && [ -x /usr/lib/smlnj/bin/sml ]; then
    SMLNJ_HOME=/usr/lib/smlnj
    export SMLNJ_HOME
fi
find_sml() {
    if [ -n "${SML:-}" ]; then
        command -v "$SML"
    elif [ -x "${SMLNJ_HOME:-/usr/lib/smlnj}/bin/sml" ]; then
        # The distribution's outer /usr/bin/sml wrapper can lose argument quoting.
        printf '%s\n' "${SMLNJ_HOME:-/usr/lib/smlnj}/bin/sml"
    else
        command -v sml
    fi
}
