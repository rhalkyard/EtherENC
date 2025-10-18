# Simple Makefile for WinCUPL's ATF150x workflow, using prjbureau to generate an
# SVF file without having to mess with ATMISP. Requires WINE, a WinCUPL
# installation, Git, and Python 3.x with virtualenv

DEVICE = p1502t44

WINE = wine
PYTHON3 = python3
PRJBUREAU = $(PWD)/prjbureau
WINCUPL_PATH = ~/.wine/drive_c/Wincupl

CUPL = $(WINCUPL_PATH)/Shared/cupl.exe
CUPL_DL = $(WINCUPL_PATH)/Shared/cupl.dl
FITTER = $(WINCUPL_PATH)/WinCupl/Fitters/fit1502.exe

.PHONY: all clean nuke

all: etherenc.svf

clean:
	rm -rf *.doc *.fit *.io *.lst *.pin *.pla *.svf *.tt2 *.tt3

nuke: clean
	rm -rf prjbureau/

prjbureau:
	git clone https://github.com/whitequark/prjbureau.git $(PRJBUREAU)
	$(PYTHON3) -m virtualenv $(PRJBUREAU)/venv
	$(PRJBUREAU)/venv/bin/pip install bitarray

%.doc %.lst %.pla %.tt2: %.pld
	$(WINE) $(CUPL) -l -b -m4 -x -f -n -u $(CUPL_DL) $<

%.fit %.io %.pin %.tt3 %.jed: %.tt2 %.pla
	$(WINE) $(FITTER) -CUPL -device $(DEVICE) -i $<

%.svf: %.jed prjbureau
	PYTHONPATH="$(PRJBUREAU)" "$(PRJBUREAU)/venv/bin/python3" -m util.fuseconv $< $@
