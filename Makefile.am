SUBDIRS            = src man test
doc_DATA           = README.md LICENSE ChangeLog.md
EXTRA_DIST         = README.md LICENSE ChangeLog.md

## Check if tagged in git
release-hook:
	if [ ! `git tag -l v$(PACKAGE_VERSION) | grep $(PACKAGE_VERSION)` ]; then	\
		echo;									\
		printf "\e[1m\e[41mCannot find release tag $(PACKAGE_VERSION)\e[0m\n";	\
		printf "\e[1m\e[5mDo release anyway?\e[0m "; read yorn;			\
		if [ "$$yorn" != "y" -a "$$yorn" != "Y" ]; then				\
			printf "OK, aborting release.\n";				\
			exit 1;								\
		fi;									\
		echo;									\
	else										\
		echo;									\
		printf "\e[1m\e[42mFound GIT release tag $(PACKAGE_VERSION)\e[0m\n";	\
		printf "\e[1m\e[44m>>Remember to push tags!\e[0m\n";			\
		echo;									\
	fi

## Generate .deb package
package build-deb:
	@debuild -uc -us -B --lintian-opts --profile debian -i -I --show-overrides

## Target to run when building a release
release: release-hook distcheck
	@mv $(DIST_ARCHIVES) ../
	@echo
	@echo "Resulting release files:"
	@echo "================================================================="
	@for file in $(DIST_ARCHIVES); do						\
		printf "%-32s Distribution tarball\n" $$file;				\
	done
