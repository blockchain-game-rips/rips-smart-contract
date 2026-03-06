.PHONY: check fix scaffold

TREE_PATH ?= test/**/*.tree

check:
	bulloak check $(TREE_PATH)

fix:
	bulloak check --fix $(TREE_PATH) && forge fmt

scaffold:
	bulloak scaffold -w $(TREE_PATH) && forge fmt
