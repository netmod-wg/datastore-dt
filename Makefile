# In case your system doesn't have any of these tools:
# https://pypi.python.org/pypi/xml2rfc
# https://github.com/Juniper/libslax/tree/master/doc/oxtradoc

xml2rfc ?= xml2rfc
oxtradoc ?= oxtradoc
idnits ?= idnits
pyang ?= pyang

draft := $(basename $(lastword $(sort $(wildcard draft-*.xml)) $(sort $(wildcard draft-*.md)) $(sort $(wildcard draft-*.org)) ))

examples = $(wildcard ex-*.xml)
load=$(patsubst ex-%.xml,ex-%.load,$(examples))
trees =

ifeq (,$(draft))
$(warning No file named draft-*.md or draft-*.xml or draft-*.org)
$(error Read README.md for setup instructions)
endif

draft_type := $(suffix $(firstword $(wildcard $(draft).md $(draft).org $(draft).xml) ))

current_ver := $(shell git tag | grep '$(draft)-[0-9][0-9]' | tail -1 | sed -e"s/.*-//")
ifeq "${current_ver}" ""
next_ver ?= 00
else
next_ver ?= $(shell printf "%.2d" $$((1$(current_ver)-99)))
endif
next := $(draft)-$(next_ver)

std-yang := $(wildcard ietf*.yang)

ex-yang := $(wildcard ex*.yang)

yang := $(std-yang) $(ex-yang)

.PHONY: latest submit clean validate

submit: $(next).txt

latest: $(draft).txt

idnits: $(next).txt
	$(idnits) $<

clean:
	-rm -f $(draft).txt back.xml $(load)
	-rm -f *.dsrl *.rng *.sch
	-rm -f $(next).txt
	-rm -f $(draft)-[0-9][0-9].xml
ifeq (.md,$(draft_type))
	-rm -f $(draft).xml
endif
ifeq (.org,$(draft_type))
	-rm -f $(draft).xml
endif

%.load: %.xml
	 cat $< | awk -f fix-load-xml.awk > $@
.INTERMEDIATE: $(load)

example-system.oper.yang: example-system.yang
	grep -v must $< > $@
.INTERMEDIATE: example-system.oper.yang

validate: validate-std-yang validate-ex-yang validate-ex-xml

validate-std-yang:
	pyang --ietf $(std-yang)

validate-ex-yang:
	pyang --canonical $(ex-yang)

validate-ex-xml: ietf-yang-architecture.yang example-system.yang \
	example-system.oper.yang
	yang2dsdl -j -t data -v ex-intended.xml $< example-system.yang
	yang2dsdl -j -t data -v ex-applied.xml $< example-system.yang
	yang2dsdl -j -t data -v ex-oper.xml $< example-system.oper.yang

back.xml: back.xml.src
	./mk-back $< > $@

$(next).xml: $(draft).xml
	sed -e"s/$(basename $<)-latest/$(basename $@)/" $< > $@

$(draft).xml: back.xml $(trees) $(load) $(yang)

.INTERMEDIATE: $(draft).xml

%.xml: %.org
	$(oxtradoc) -m outline-to-xml -n "$(basename $<)-latest" $< > $@

%.txt: %.xml
	$(xml2rfc) $< -o $@ --text

%.tree: %.yang
	$(pyang) -f tree --tree-line-length 68 $< > $@
