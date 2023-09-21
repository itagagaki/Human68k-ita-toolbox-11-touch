# Makefile for ITA TOOLBOX #11 touch

AS	= HAS.X -i $(INCLUDE)
LK	= hlk.x -x
CV      = -CV.X -r
CP      = cp
RM      = -rm -f

INCLUDE = $(HOME)/fish/include

DESTDIR   = A:/usr/ita
BACKUPDIR = B:/touch/1.5
RELEASE_ARCHIVE = TOUCH15
RELEASE_FILES = MANIFEST README ../NOTICE CHANGES touch.1 touch.x

EXTLIB = ../lib/getlnenv.o $(HOME)/fish/lib/ita.l

###

PROGRAM = touch.x

###

.PHONY: all clean clobber install release backup

.TERMINAL: *.h *.s

%.r : %.x	; $(CV) $<
%.x : %.o	; $(LK) $< $(EXTLIB)
%.o : %.s	; $(AS) $<

###

all:: $(PROGRAM)

clean::

clobber:: clean
	$(RM) *.bak *.$$* *.o *.x

###

$(PROGRAM) : $(INCLUDE)/doscall.h $(INCLUDE)/error.h $(INCLUDE)/stat.h $(INCLUDE)/chrcode.h $(EXTLIB)

include ../Makefile.sub

###
