VERSION=`cat VERSION`

.PHONY: build_gtk
build_gtk:
	@echo Building Drill $(VERSION) GTK...
	@dub build -b release -c GTK > /dev/null
	@echo Building Drill $(VERSION) GTK... OK

.PHONY: build_cli
build_cli:

	@echo Building Drill $(VERSION) CLI...
	@cd CLI && cmake . && make -j
	@echo Building Drill $(VERSION) CLI... OK

.PHONY: build_nwjs
build_nwjs: build_cli
ifeq (, $(shell which npm))
	$(error "No npm in $(PATH), consider installing it")
endif
	@echo Cleaning previous NWjs build...
	@rm -rf Build/NWjs
	@echo Cleaning previous NWjs build... OK
	@echo Building NWjs...
	@mkdir -p Build/NWjs
	@cp -r NWjs/* Build/NWjs
	@echo Installing NPM modules...  > /dev/null
	@cd Build/NWjs && npm install && cd ../../
	@echo Installing NPM modules... OK
	@echo Building NWjs... OK
	@echo Copying Drill files...
	@cp -r Build/CLI/* Build/NWjs
	@echo Copying Drill files... OK

.PHONY: run_gtk
run_gtk: build_gtk
	@dub run -b release -c GTK > /dev/null

.PHONY: run_nwjs
run_nwjs: build_nwjs
ifeq (, $(shell which nw))
	$(error "No nw in $(PATH), consider installing it")
endif
	@nw Build/NWjs
	
.PHONY: create_appimage
create_appimage: build_nwjs
ifeq (, $(shell which appstreamcli))
	$(error "No appstreamcli in $(PATH), consider installing it")
endif

.PHONY: run_appimage
run_appimage: create_appimage
	./Build/Drill-$(VERSION)-x86_64.AppImage
