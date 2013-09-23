SOURCEMOD=../sourcemod/sourcemod-1.5.0-hg3832/addons/sourcemod/scripting
CURL=../sourcemod/curl/scripting/include
PLUGINS=addons/sourcemod/plugins
SCRIPTING=addons/sourcemod/scripting

# Get the version number from the source file
VERSION=$(shell grep 'define MDBVERSION' addons/sourcemod/scripting/mitchdb.sp | grep -o '".*"' | sed 's/"//g')

compile: clean
	$(SOURCEMOD)/spcomp $(SCRIPTING)/mitchdb.sp -o$(PLUGINS)/mitchdb.smx -i$(SCRIPTING) -i$(SOURCEMOD)/include -i$(CURL) -v2

clean:
	rm -f $(PLUGINS)/mitchdb.smx

zip: compile
	rm -f mitchdb.zip
	zip -r mitchdb.zip $(PLUGINS)/mitchdb.smx

tag: compile

	# Ensure that the working tree is clean
	@if test 0 -ne `git status --porcelain | wc -l` ; then \
		echo "Unclean working tree. Commit or stash changes first." >&2 ; \
		exit 128 ; \
		fi

	# Make sure that we haven't already released this version
	@if test 0 -ne `git tag -l v${VERSION} | wc -l` ; then \
		echo "Tag v${VERSION} exists. Update package.json" >&2 ; \
		exit 128 ; \
		fi

	# Tag the release
	git tag -a v$(VERSION) -m "Releasing $(VERSION)"

	# Push release to github
	git push --tags