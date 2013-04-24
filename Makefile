
SPCOMP=addons/sourcemod/scripting/spcomp
PLUGIN_PATH=addons/sourcemod/plugins
SPINCLUDE=addons/sourcemod/scripting

compile: clean
	$(SPCOMP) $(SPINCLUDE)/mitchdb.sp -o$(PLUGIN_PATH)/mitchdb.smx -i$(SPINCLUDE) -i$(SPINCLUDE)/include -v2

clean:
	rm -f $(PLUGIN_PATH)/mitchdb.smx

zip: compile
	zip -r mitchdb.zip addons
