INPUTS=examples/hello-world.bf examples/test-z.bf

all: main

.PHONY: test
test: main $(INPUTS)
	echo; for f in $(INPUTS); do echo "*** $$f"; ./nbf $$f; echo; done

main: main.nim
	nim compile \
		--verbosity:0 \
		--out:./nbf --outdir:. \
		--warningAsError:Uninit:on \
		--experimental:strictDefs \
		main.nim
