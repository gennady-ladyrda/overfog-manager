.PHONY: test test-shell

test:
	python -m unittest discover -s tests -v

test-shell:
	sh tests/shell/test_cli.sh
