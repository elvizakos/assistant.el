VERSION:=0.9.13
PACKAGE_NAME:=assistant-mode-$(VERSION)
PACKAGE_DIR:=/tmp/$(PACKAGE_NAME)

package: $(PACKAGE_DIR)
	tar cvf ../$(PACKAGE_NAME).tar --exclude="*#" --exclude="*~" --exclude="Makefile" --exclude="ChangeLog" --exclude="ChangeLog" --exclude="COPYING" --exclude="*.gif" --exclude="*.md" --exclude="*.org" -C $(PACKAGE_DIR)/.. $(PACKAGE_NAME)

$(PACKAGE_DIR):
	mkdir $@
	echo "" > assistant-mode-autoloads
	cp -r ./* $@
	sed -re "s/VERSION/$(VERSION)/g" $@/assistant-mode-pkg.el > $@/"~tmp~"
	mv $@/"~tmp~" $@/assistant-mode-pkg.el
	sed -re 's/%%VERSION%%/'"$(VERSION)"'/g' $@/assistant-mode.el > $@/"~tmp~"
	sed -re 's/\(defconst assistant-version \"%%VERSION%%\"/\(defconst assistant-version "'"$(VERSION)"'"/g' $@/"~tmp~" > $@/assistant-mode.el
	rm $@/"~tmp~"

install:
	tar -xvf ../$(PACKAGE_NAME).tar -C ~/.emacs.d/elpa/

remove:
	rm -rf ~/.emacs.d/elpa/$(PACKAGE_NAME)

clean:
	rm -f ../$(PACKAGE_NAME).tar
	rm -rf $(PACKAGE_DIR)

#end

