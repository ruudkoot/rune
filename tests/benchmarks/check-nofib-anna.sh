#!/bin/sh
set -eu
exec sh "$(dirname "$0")/check-nofib-applications.sh" anna
