##
##  k8s-util -- Kubernetes (K8S) Utility
##  Copyright (c) 2019-2020 Dr. Ralf S. Engelschall <rse@engelschall.com>
##
##  Permission is hereby granted, free of charge, to any person obtaining
##  a copy of this software and associated documentation files (the
##  "Software"), to deal in the Software without restriction, including
##  without limitation the rights to use, copy, modify, merge, publish,
##  distribute, sublicense, and/or sell copies of the Software, and to
##  permit persons to whom the Software is furnished to do so, subject to
##  the following conditions:
##
##  The above copyright notice and this permission notice shall be included
##  in all copies or substantial portions of the Software.
##
##  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
##  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
##  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
##  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
##  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
##  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
##  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
##

PREFIX  = /usr/local
BINDIR  = $(PREFIX)/bin
ETCDIR  = $(PREFIX)/etc/k8s-util
MANDIR  = $(PREFIX)/man/man1
DESTDIR =

all: k8s-util.1

bootstrap:
	@if [ ! -d node_modules ]; then npm install remark-cli remark remark-man; fi

k8s-util.1: bootstrap k8s-util.md
	npx remark --use remark-man --output k8s-util.1 k8s-util.md

install: k8s-util.1
	install -d $(DESTDIR)$(BINDIR)
	sed -e 's;^\(my_config="\).*\("\);\1$(ETCDIR)/k8s-util.yaml\2;' <k8s-util.bash >tmpfile && \
	    install -c -m 755 tmpfile $(DESTDIR)$(BINDIR)/k8s-util && \
	    rm -f tmpfile
	install -d $(DESTDIR)$(ETCDIR)
	install -c -m 755 k8s-util.yaml $(DESTDIR)$(BINDIR)/k8s-util.yaml
	install -d $(DESTDIR)$(MANDIR)
	install -c -m 755 k8s-util.1 $(DESTDIR)$(MANDIR)/k8s-util.1

clean:
	rm -f k8s-util.1

distclean:
	rm -rf node_modules

