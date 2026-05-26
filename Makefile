# ============================================================
#  Makefile — LaTeX Docker compiler
#  Uso: make build | make pdf FILE=main.tex | make clean
# ============================================================

IMAGE   ?= latex-full
TAG     ?= 2025
WORKDIR ?= $(shell pwd)
FILE    ?= main.tex

# Flags por defecto (shell-escape para svg/minted)
COMPILE_FLAGS ?= --engine pdflatex --shell-escape --bib bibtex --verbosity warn --clean
DOCKER_USER ?= $(shell id -u):$(shell id -g)

# ──────────────────────────────────────────────────────────────
build:
	@echo "▶ Construyendo imagen $(IMAGE):$(TAG)..."
	docker build -f docker/Dockerfile -t $(IMAGE):$(TAG) .
	@echo "✓ Imagen lista: $(IMAGE):$(TAG)"

# Compilar un documento
pdf:
	docker run --rm \
	  --user "$(DOCKER_USER)" \
	  -v "$(WORKDIR):/workspace" \
	  $(IMAGE):$(TAG) \
	  $(COMPILE_FLAGS) $(FILE)

# Compilar sin limpiar auxiliares (útil para depurar)
pdf-debug:
	docker run --rm \
	  --user "$(DOCKER_USER)" \
	  -v "$(WORKDIR):/workspace" \
	  $(IMAGE):$(TAG) \
	  --engine pdflatex --shell-escape --bib bibtex $(FILE)

# Compilar mostrando absolutamente TODO (Tu anterior comportamiento por si acaso)
pdf-verbose:
	docker run --rm \
	  --user "$(DOCKER_USER)" \
	  -v "$(WORKDIR):/workspace" \
	  $(IMAGE):$(TAG) \
	  --engine pdflatex --shell-escape --bib bibtex --verbosity all $(FILE)

# Compilar de forma ultra silenciosa: Sólo errores críticos
pdf-silent:
	docker run --rm \
	  --user "$(DOCKER_USER)" \
	  -v "$(WORKDIR):/workspace" \
	  $(IMAGE):$(TAG) \
	  --engine pdflatex --shell-escape --bib bibtex --verbosity error $(FILE)

# Limpiar archivos auxiliares, logs y directorios generados por Inkscape/SVG
clean:
	@echo "Limpiando archivos auxiliares de LaTeX..."
	rm -rf *.aux *.bbl *.bcf *.blg *.fls *.fdb_latexmk *.log *.out *.run.xml *.toc *.lof *.lot
	@echo "Eliminando carpetas de imágenes SVG vectorizadas..."
	rm -rf svg-inkscape/ pythontex-files-*/ *~
	@echo "✓ Directorio limpio."

# Limpiar todo y compilar desde cero en un solo comando
scratch: clean pdf

# Shell interactivo dentro del contenedor
shell:
	docker run --rm -it \
	  --user "$(DOCKER_USER)" \
	  -v "$(WORKDIR):/workspace" \
	  --entrypoint bash \
	  $(IMAGE):$(TAG)

# Borrar imagen y caché por completo
nuke:
	docker rmi $(IMAGE):$(TAG) --force 2>/dev/null || true
	docker builder prune -af
	docker system prune -f
	@echo "✓ Imagen y caché eliminados"

.PHONY: build pdf pdf-debug pdf-verbose pdf-silent clean scratch shell nuke
