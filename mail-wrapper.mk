#!/usr/bin/make -f

top:; @date

SHELL := bash

self := $(firstword $(MAKEFILE_LIST))
self.base := $(basename $(self))
self.cmd := $(self.base).pl

$(self):;

####

bin := /usr/local/bin
user := root
group := staff
install.cmd = install --backup=numbered -o $(user) -g $(group) -m $1 $< $@
install := $(bin)/$(self.cmd)
$(install): $(bin)/% : %; $(call install.cmd,555)
install: $(install)

####

thy := thy@nowhere.tld

/proc/uptime:;

isilon.lines := grep isilon $(self) | md5sum
isilon.dep = $(shell cmp -s <($(isilon.lines)) isilon.md5sum || echo /proc/uptime)
isilon.md5sum:; $(isilon.lines) > $@

isilon.hide := -h $$'^\043 (date|blog|rsync)/[\da-f]{3} :'
isilon.hide := $(foreach _,date blog rsync,--hidep $$'^\043 $_/[\da-f]{3} :')
isilon.subject := 'flxblog backup bck01'

isilon.out isilon.in:;
isilon.tst: isilon.in $(isilon.dep); perl $(self.cmd) -no-mail -s $(isilon.subject) $(isilon.hide) $< > $@
isilon: isilon.out isilon.tst; diff $^

isilon.log: isilon.in $(isilon.dep); perl $(self.cmd) -no-mail --logfile $@ -s $(isilon.subject) $(isilon.hide) $<

# start centralized-backup-disabled

cbd := centralized-backup-disabled

cbd.mark := $(cbd)
cbd.lines := sed -ne '/^. start $(cbd.mark)/,/^. end $(cbd.mark)/p' $(self)
cbd.md5sum := $(cbd.lines) | md5sum 
cbd.dep = $(shell cmp -s <($(cbd.md5sum)) cbd.md5sum || echo /proc/uptime)
$(cbd).md5sum:; $(cbd.md5sum) > $@

cbd.warn := --warnp ' - WARNING [-\w]+ disabled$$'
cbd.subject := 'flxbdb backup mogdb2-ng on bck04'
$(cbd).out $(cbd).in:;
$(cbd).tst: $(cbd).in; perl $(self.cmd) -no-mail -s $(cbd.subject) $(cbd.warn) $< > $@
$(cbd): $(cbd).out $(cbd).tst; diff $^
cbd: $(cbd);

cbd.mif: $(cbd).in; perl $(self.cmd) --mailiferror --logfile $($(basename $@)).log -s $(cbd.subject) $(cbd.warn) $<

# end centralized-backup-disabled

cbe := centralized-backup-error
cbe.error := --errorp '\*\*\* ERROR \*\*\*'
cbe.subject := 'flxbdb backup mogdb2-ng on bck04'
$(cbe).in:;
$(cbe).mif: $(cbe).in; perl $(self.cmd) --mailiferror --logfile $(basename $@).log -s $(cbe.subject) $(cbe.error) $<
cbe: $(cbe).mif;

####

md5sum := isilon.md5sum $(cbd).md5sum
md5sum: clear-md5sum $(md5sum);
clear-md5sum:; rm -f $(md5sum)

.PHONY: md5sum;

####

$(self.base).wiki: $(self.cmd); pod2wiki -s moinmoin $< > $@
wiki: $(self.base).wiki;

####

ci := -m ''
st di up ci:; svn $@ $($@)

ignore := -F .svnignore .
keywords := "Date Revision Author URL" $(self) $(self.cmd)
ignore keywords:; svn pset svn:$@ $($@)
