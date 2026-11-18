MAIN=informe_pedp

all: $(MAIN).pdf

$(MAIN).pdf: $(MAIN).tex literatura.bib instructivo.sty fig/*
	pdflatex -interaction=batchmode $(MAIN)
	biber $(MAIN)
	pdflatex -interaction=batchmode $(MAIN)
	pdflatex -interaction=batchmode $(MAIN)

figuras:
	octave --no-gui -q --eval "figuras_informe()"

clean:
	rm -f $(MAIN).aux $(MAIN).bbl $(MAIN).bcf $(MAIN).blg $(MAIN)-blx.bib $(MAIN).log $(MAIN).out $(MAIN).run.xml $(MAIN).thm $(MAIN).toc

.PHONY: all figuras clean
