# ============================================================
#  LaTeX Compiler — Full TeX Live (Overleaf-equivalent)
#  Motor: pdfLaTeX  |  Base: texlive/texlive:latest (TL 2025)
# ============================================================
FROM texlive/texlive:latest

LABEL maintainer="tu@email.com"
LABEL description="Full TeX Live for complex LaTeX docs (pdflatex, xelatex, lualatex)"

# ── Dependencias del sistema ────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # SVG → PDF (necesario para el paquete svg)
    inkscape \
    # Manipulación de PS/PDF
    ghostscript \
    # Python para Pygments (minted / listings con highlight)
    python3 \
    python3-pygments \
    # Herramientas auxiliares
    make \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# ── Actualizar tlmgr y paquetes clave ──────────────────────
# texlive/texlive:latest ya trae scheme-full; esto sólo
# garantiza que los paquetes usados estén al día.
RUN tlmgr update --self --all --no-auto-install 2>/dev/null || true

# ── Directorio de trabajo ───────────────────────────────────
WORKDIR /workspace

# ── Script de compilación "inteligente" ────────────────────
# Realiza las pasadas necesarias para resolver refs, ToC,
# bibliografía (BibTeX/biber) y lo que haga falta.
COPY scripts/compile.sh /usr/local/bin/compile
RUN chmod 755 /usr/local/bin/compile
RUN chown root:root /usr/local/bin/compile

# Asegurar que el entrypoint es ejecutable por cualquier usuario
RUN chmod 755 /usr/local/bin/compile

# ENTRYPOINT flexible: usa 'compile' por defecto,
# pero puedes llamar directamente a pdflatex/latexmk/etc.
ENTRYPOINT ["compile"]
CMD ["--help"]
