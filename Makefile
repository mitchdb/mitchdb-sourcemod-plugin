SOURCEMOD=../sourcemod/sourcemod-1.5.0-hg3832/addons/sourcemod/scripting
CURL=../sourcemod/curl/scripting/include
PLUGINS=addons/sourcemod/plugins
SCRIPTING=addons/sourcemod/scripting

compile: clean
	$(SOURCEMOD)/spcomp $(SCRIPTING)/mitchdb.sp -o$(PLUGINS)/mitchdb.smx -i$(SCRIPTING) -i$(SOURCEMOD)/include -i$(CURL) -v2

clean:
	rm -f $(PLUGINS)/mitchdb.smx

zip: compile
	rm -f mitchdb.zip
	zip -r mitchdb.zip $(PLUGINS)/mitchdb.smx
