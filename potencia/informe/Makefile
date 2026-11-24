DOCS=informe_diseno_pedp informe_tecnico_pedp

all: $(DOCS:=.pdf)

%.pdf: %.tex preambulo.tex literatura.bib instructivo.sty fig/*
	pdflatex -interaction=batchmode $*
	biber $*
	pdflatex -interaction=batchmode $*
	pdflatex -interaction=batchmode $*

figuras:
	octave --no-gui -q --eval "figuras_informe()"

clean:
	rm -f $(foreach d,$(DOCS),$(d).aux $(d).bbl $(d).bcf $(d).blg $(d)-blx.bib $(d).log $(d).out $(d).run.xml $(d).thm $(d).toc)

.PHONY: all figuras clean
