VERSION:=$(shell git -C ../assistant describe --tags --abbrev=0 | sed 's/^v//')
PACKAGE_NAME:=assistant-mode-$(VERSION)
PACKAGE_DIR:=/tmp/$(PACKAGE_NAME)

package: $(PACKAGE_DIR)
	tar cvf ../$(PACKAGE_NAME).tar  --exclude="*#" \
									--exclude="*~" \
									--exclude="Makefile" \
									--exclude="ChangeLog" \
									--exclude="COPYING" \
									--exclude="*.gif" \
									--exclude="*.md" \
									--exclude="*.org" \
									--exclude="assistant.sh" \
									--exclude="setver" \
									--exclude="tests.el" \
									--exclude="tests" \
									--exclude="tests/*" \
									-C $(PACKAGE_DIR)/.. $(PACKAGE_NAME)

$(PACKAGE_DIR):
	mkdir -p $@
	cp -r ./* $@
	sed -re "s/VERSION/$(VERSION)/g" $@/assistant-mode-pkg.el > $@/"~tmp~"
	mv $@/"~tmp~" $@/assistant-mode-pkg.el
	sed -re 's/%%VERSION%%/'"$(VERSION)"'/g' $@/assistant-mode.el > $@/"~tmp~"
	sed -re 's/\(defconst assistant-version \"%%VERSION%%\"/\(defconst assistant-version "'"$(VERSION)"'"/g' $@/"~tmp~" > $@/assistant-mode.el
	rm $@/"~tmp~"

install:
	tar -xvf ../$(PACKAGE_NAME).tar -C /tmp/
	emacs --batch --eval "\
		(progn \
			(require 'package) \
			(package-initialize) \
			(package-install-file \"/tmp/$(PACKAGE_NAME)\"))"

remove:
	emacs --batch --eval "\
		(progn \
			(require 'package) \
			(package-initialize) \
			(package-delete (cadr (assq 'assistant-mode package-alist))))"
	rm -rf ~/.emacs.d/elpa/$(PACKAGE_NAME)

clean:
	rm -f ../$(PACKAGE_NAME).tar
	rm -rf $(PACKAGE_DIR)
	rm -rf /tmp/$(PACKAGE_NAME)

#end

