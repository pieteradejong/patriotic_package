#!/usr/bin/env bash
# Start the dev server. First run: ./init.sh.
#   ./run.sh            dev server on http://localhost:4321/
#   ./run.sh build      production build into dist/
#   ./run.sh preview    serve dist/ locally (a background daemon; ./run.sh stop ends it)
#   ./run.sh stop       stop the dev and preview servers
#   ./run.sh lint       shellcheck the scripts and type-check the site
#   ./run.sh type-check astro check only
#   ./run.sh test …     run ./test.sh with the given flags (e.g. --live <url>)
set -euo pipefail
cd "$(dirname "$0")"
case "${1:-}" in
	-h|--help|help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
	test)           shift; exec ./test.sh "$@" ;;
esac

[ -d node_modules ] || { echo "node_modules missing — running ./init.sh first"; ./init.sh; }

case "${1:-dev}" in
	dev)     exec npm run dev ;;
	build)   exec npm run build ;;
	preview) exec npm run preview ;;
	lint)       shellcheck -S warning init.sh run.sh test.sh && exec npx astro check ;;
	type-check) exec npx astro check ;;
	stop)    npx astro dev stop >/dev/null 2>&1 || true; npx astro preview stop >/dev/null 2>&1 || true ;;
	*)       echo "usage: ./run.sh [dev|build|preview|lint|type-check|stop|test|help]" >&2; exit 2 ;;
esac
