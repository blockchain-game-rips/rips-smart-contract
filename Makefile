.PHONY: check fix scaffold local

P ?= test/**/*.tree

check:
	bulloak check $(P)

fix:
	bulloak check --fix $(P) && forge fmt

scaffold:
	bulloak scaffold -w $(P) && forge fmt

local:
	sh local/setup.sh
