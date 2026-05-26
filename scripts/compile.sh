#!/usr/bin/env bash
# ============================================================
#  compile.sh — compilador LaTeX multi-pasada (Filtrado Inteligente)
#  Uso dentro del contenedor (vía ENTRYPOINT)
# ============================================================
set -euo pipefail

# ── Colores ─────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERR ]${NC}  $*"; exit 1; }

usage() {
cat <<EOF

  ${CYAN}compile${NC} — compilador LaTeX (pdflatex + bibtex/biber, multi-pasada)

  Uso:
    compile [OPCIONES] <archivo.tex>

  Opciones:
    -e, --engine ENGINE   Motor LaTeX: pdflatex | xelatex | lualatex
                          (defecto: pdflatex)
    -b, --bib BIB_ENGINE  Motor bibliografía: bibtex | biber | none
                          (defecto: bibtex)
    -p, --passes N        Número de pasadas LaTeX (defecto: 3)
    -o, --output DIR      Directorio de salida del PDF (defecto: mismo que .tex)
    -s, --shell-escape    Activa -shell-escape (necesario para svg, minted)
    -v, --verbosity LEVEL Nivel de salida: error | warn | all
                          (defecto: all)
    -c, --clean           Elimina auxiliares tras compilar
    -h, --help            Muestra esta ayuda

  Ejemplos:
    compile main.tex
    compile --verbosity error main.tex
    compile -e xelatex -v warn main.tex

EOF
exit 0
}

# ── Valores por defecto ─────────────────────────────────────
ENGINE="pdflatex"
BIB_ENGINE="bibtex"
PASSES=3
OUTPUT_DIR=""
SHELL_ESCAPE=false
VERBOSITY="all"
CLEAN=false
TEX_FILE=""

# ── Parse de argumentos ─────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--engine)        ENGINE="$2";        shift 2 ;;
    -b|--bib)           BIB_ENGINE="$2";    shift 2 ;;
    -p|--passes)        PASSES="$2";        shift 2 ;;
    -o|--output)        OUTPUT_DIR="$2";    shift 2 ;;
    -s|--shell-escape)  SHELL_ESCAPE=true;  shift   ;;
    -v|--verbosity)     VERBOSITY="$2";     shift 2 ;;
    -c|--clean)         CLEAN=true;         shift   ;;
    -h|--help)          usage ;;
    *.tex)              TEX_FILE="$1";      shift   ;;
    *)  error "Argumento desconocido: $1. Usa --help para ver la ayuda." ;;
  esac
done

[[ -z "$TEX_FILE" ]] && usage
[[ ! -f "$TEX_FILE" ]] && error "Archivo no encontrado: $TEX_FILE"
[[ ! "$VERBOSITY" =~ ^(error|warn|all)$ ]] && error "Nivel de verbosidad inválido: $VERBOSITY. Usa: error, warn o all."

# ── Rutas ───────────────────────────────────────────────────
TEX_DIR="$(cd "$(dirname "$TEX_FILE")" && pwd)"
TEX_BASE="$(basename "$TEX_FILE" .tex)"
OUTPUT_DIR="${OUTPUT_DIR:-$TEX_DIR}"
mkdir -p "$OUTPUT_DIR"

# ── Flags del motor ─────────────────────────────────────────
ENGINE_FLAGS=(
  -interaction=nonstopmode
  -file-line-error
  -output-directory="$OUTPUT_DIR"
)
$SHELL_ESCAPE && ENGINE_FLAGS+=(-shell-escape)

cd "$TEX_DIR"

# ── Función de filtrado dinámico ────────────────────────────
filter_output() {
  if [[ "$VERBOSITY" == "all" ]]; then
    # Deja pasar todo de forma nativa
    cat
  elif [[ "$VERBOSITY" == "warn" ]]; then
    # Muestra líneas de error clásicas de LaTeX, formato file:line:error y Advertencias
    # Evita la basura de "Underfull/Overfull \hbox" para no saturar
    grep -E -i "error|^! |:[0-9]+:|warning|latex warn" | grep -v -E "Overfull|Underfull" || true
  elif [[ "$VERBOSITY" == "error" ]]; then
    # Filtra de forma estricta buscando sólo el indicador de error de TeX y la estructura file:line
    grep -E -i "error|^! |:[0-9]+:" || true
  fi
}

# ── Función: una pasada LaTeX ────────────────────────────────
run_latex() {
  local pass=$1
  info "Pasada LaTeX ${pass}/${PASSES} con ${ENGINE}..."

  # Ejecutamos el motor, redirigimos stderr a stdout para filtrarlo todo junto,
  # aplicamos el filtro dinámico y guardamos el exit code original de LaTeX
  set +e
  "$ENGINE" "${ENGINE_FLAGS[@]}" "$TEX_BASE.tex" 2>&1 | filter_output
  local exit_code=${PIPESTATUS[0]}
  set -e

  if [ $exit_code -ne 0 ]; then
    echo -e "${RED}──────────────────────────────────────────────────────────────"
    echo -e "   [!] DETECTADO ERROR CRÍTICO EN LA PASADA ${pass}"
    echo -e "──────────────────────────────────────────────────────────────${NC}"
    # Si estábamos filtrando, mostramos las últimas líneas del archivo .log real para dar contexto inmediato
    if [[ "$VERBOSITY" != "all" ]]; then
      warn "Últimas líneas relevantes del archivo .log:"
      tail -n 20 "$OUTPUT_DIR/$TEX_BASE.log" | grep -A 5 -B 5 -E -i "error|^!" || tail -n 15 "$OUTPUT_DIR/$TEX_BASE.log"
    fi
    error "Falló ${ENGINE} en la pasada ${pass}. Revisa el archivo: $OUTPUT_DIR/$TEX_BASE.log"
  fi
}

# ── Función: bibliografía ───────────────────────────────────
run_bib() {
  if [[ "$BIB_ENGINE" == "none" ]]; then
    return
  fi
  local bib_input="$OUTPUT_DIR/$TEX_BASE"
  if [[ "$BIB_ENGINE" == "bibtex" ]]; then
    if grep -q "\\\\bibdata" "$OUTPUT_DIR/$TEX_BASE.aux" 2>/dev/null; then
      info "Ejecutando bibtex..."
      bibtex "$TEX_BASE" > /dev/null || warn "bibtex terminó con advertencias (revisa el .blg)"
      # bibtex "$bib_input" > /dev/null || warn "bibtex terminó con advertencias (revisa el .blg)"
    else
      warn "No se encontró \\bibdata en el .aux; omitiendo bibtex"
    fi
  elif [[ "$BIB_ENGINE" == "biber" ]]; then
    if grep -q "\\\\abx@aux@refcontext" "$OUTPUT_DIR/$TEX_BASE.aux" 2>/dev/null; then
      info "Ejecutando biber..."
      # biber "$bib_input" > /dev/null || warn "biber terminó con advertencias"
      biber "$TEX_BASE" > /dev/null || warn "biber terminó con advertencias"
    else
      warn "No se detectó biblatex en el .aux; omitiendo biber"
    fi
  fi
}

# ── Compilación ─────────────────────────────────────────────
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "Documento  : $TEX_BASE.tex"
info "Motor      : $ENGINE"
info "Bibliog.   : $BIB_ENGINE"
info "Pasadas    : $PASSES"
info "Verbosity  : $VERBOSITY"
info "Salida     : $OUTPUT_DIR"
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_latex 1
run_bib

for ((i=2; i<=PASSES; i++)); do
  run_latex "$i"
done

# ── Resultado ───────────────────────────────────────────────
PDF="$OUTPUT_DIR/$TEX_BASE.pdf"
if [[ -f "$PDF" ]]; then
  ok "PDF generado: $PDF"
else
  error "No se generó el PDF. Revisa $OUTPUT_DIR/$TEX_BASE.log"
fi

# ── Limpieza ────────────────────────────────────────────────
if $CLEAN; then
  info "Eliminando archivos auxiliares y directorios temporales..."
  local_clean=(aux bbl bcf blg fls fdb_latexmk log out run.xml toc lof lot)
  for ext in "${local_clean[@]}"; do
    rm -f "$OUTPUT_DIR/$TEX_BASE.$ext"
  done

  # CORREGIDO: Borrar la carpeta svg-inkscape generada en el entorno
  rm -rf "$OUTPUT_DIR/svg-inkscape" "$OUTPUT_DIR/_minted-$TEX_BASE"

  ok "Auxiliares y carpetas temporales eliminados"
fi
