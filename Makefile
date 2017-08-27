PUBLISH_DIR = ~/SharedProjects/builds/pacman-asm
NAME = pacman-app
MAIN_FILE = main.asm
EXECUTABLE = $(NAME).8xk

.PHONY: clean publish test


$(EXECUTABLE): $(MAIN_FILE)
	zapp

clean:
	rm -f pacman-app.*
	rm -f *~
	rm -f .*~

publish: $(EXECUTABLE)
	cp $(EXECUTABLE) $(PUBLISH_DIR)

test:
	cd test; zapp
