





.PHONY: all clean core


core:
	cd Core && $(MAKE)

cli:
	cd CLI && $(MAKE)

nwaddon:
	cd NWAddon && $(MAKE)

clean:
	cd Core && $(MAKE) clean
