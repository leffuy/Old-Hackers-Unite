LINKER		= g++
CXX			= g++

CXXFLAGS		= -c -g -Wall -pedantic 
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

