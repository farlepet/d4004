MAINDIR    = $(CURDIR)
SRC        = $(MAINDIR)/src

OUT        = $(MAINDIR)/d4004
INSTALL    = /usr/bin/$(OUT)

SRCS       = $(wildcard $(SRC)/*.d)

# This compiler is much slower, but I can cut the executable size much more using `strip`
DC         = dmd

DFLAGS     = -I$(SRC)


link:   $(OBJS)
	@echo -e "\033[33m  \033[1mCompiling d4004\033[0m"
	@$(DC) $(DFLAGS) $(SRCS) -of$(OUT)
	@strip -s $(OUT)



clean:
	@echo -e "\033[33m  \033[1mCleaning sources\033[0m"
	@rm -f $(MAIN)
	@rm -f $(OUT)

install:
	@echo -e "\033[33m  \033[1mInstalling executable\033[0m"
	@cp $(OUT) $(INSTALL)