LINKER		= g++-4.5.0
CXX			= g++-4.5.0

CXXFLAGS		= -c -g -O2 -Wall -pedantic 
LFLAGS		= -lboost_program_options 

OBJS = assembler.o
FILES = assembler.cc

all: ${OBJS} assembler

assembler: ${OBJS} 
		${CXX} ${LFLAGS} ${OBJS} -o $@ 

.cc.o: ${FILES}
		${CXX} ${CXXFLAGS} $< -o $@ 

clean:
		rm ${OBJS} assembler 

