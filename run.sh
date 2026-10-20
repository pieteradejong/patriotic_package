#!/usr/bin/env bash
# Start the dev server. First run: ./init.sh.
#   ./run.sh            dev server on http://localhost:4321/
#   ./run.sh build      production build into dist/
#   ./run.sh preview    serve dist/ locally (a background daemon; ./run.sh stop ends it)
#   ./run.sh stop       stop the dev and preview servers
#   ./run.sh test …     run ./test.sh with the given flags (e.g. --live <url>)
set -euo pipefail
cd "$(dirname "$0")"
case "${1:-}" in
	-h|--help|help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
	test)           shift; exec ./test.sh "$@" ;;
esac

[ -d node_modules ] || { echo "node_modules missing — running ./init.sh first"; ./init.sh; }

case "${1:-dev}" in
	dev)     exec npm run dev ;;
	build)   exec npm run build ;;
	preview) exec npm run preview ;;
	stop)    npx astro dev stop >/dev/null 2>&1 || true; npx astro preview stop >/dev/null 2>&1 || true ;;
	*)       echo "usage: ./run.sh [dev|build|preview|stop|test|help]" >&2; exit 2 ;;
esac
