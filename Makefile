git-vain:
	cc git-vain.c -o git-vain

install: git-vain
	cp git-vain /usr/local/bin

clean:
	rm -f git-vain

