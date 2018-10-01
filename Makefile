SRCS := dummy_app.c
BINS := $(SRCS:.c=.bin)
# $(SRCS:.c=.bin) means, take the variable value ${SRCS}, which is a string composed of words
# separated by spaces, and for each word, replace the suffix .c with .bin => %.bin: target will
# run

all: ${BINS}

show: dummy_app_disasm

dummy_app.elf: vector.o start.o
# the above target is depending on the following .o files
# when ever it sees the rule %.elf: %.o this will be executed
# and corresponding .o files (intermediate) will not be deleted

include rules.mk
