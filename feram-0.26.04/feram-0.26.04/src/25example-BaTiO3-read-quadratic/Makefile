# -*-Makefile-*- for 15aBC-8
##
EPS_FILES = 

all: projection.pdf
	grep 'Warning' *.log ; true
#	osascript -e 'tell application "Preview.app" to activate'\
#                  -e 'tell application "Emacs.app"   to activate'

%.pdf: %.dvi
	dvipdfmx -f dvipdfmx.map -p a4 $< > $@

%.dvi: %.tex $(EPS_FILES)
	platex $<
#	bibtex `basename $< .tex`
#	platex $<
#	platex $<

clean:
	rm -rf *.aux *.bbl *.blg *.dvi *.log *.ps *.pdf
