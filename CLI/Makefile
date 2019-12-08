CXX      := c++
CXXFLAGS :=                  \
			-pedantic-errors \
			-Wall 			 \
			-Wextra 		 \
			-std=c++17       \
			-Wconversion
			
# Name of the build directory
BUILD    := ./Build

# Name of the directory for temporary object files
OBJ_DIR  := $(BUILD)/Objects

# Name of the directory for library file
APP_DIR  := $(BUILD)/Executable

# Headers to include
INCLUDE  := -I../Core -I../Core/spdlog/include/

# Links default libraries, C++, math and threads
LDFLAGS  := -L/usr/lib -lstdc++ -lm -lposix -L../Core/Build/Library -llibDrillCore

# Source files
SRC      := $(OBJ_DIR)/CLI.cpp

# Name of the executable
TARGET   := DrillCLI.elf

# Variable holding all object files
OBJECT := $(BUILD)/$(OBJ_DIR)/CLI.o


# We tell make that the rules with these names are not real files but just commands to execute
.PHONY: build_executable create_folders debug release clean


$(info ========== Drill CLI ==========)

# The rule to create object file: needs .cpp file
CLI.o: CLI.cpp
	$(info        Building object file)
	$(CXX) $(CXXFLAGS) $(INCLUDE) -o $(OBJ_DIR)/CLI.o CLI.cpp
	$(info [ OK ] Building object file)


# The rule to create the single executable file
# Dependencies:
# - needs object file
$(APP_DIR)/$(TARGET): $(OBJECT)
	$(info        Building executable file)
	$(CXX) $(CXXFLAGS) $(INCLUDE) $(LDFLAGS) -o $(APP_DIR)/$(TARGET) $(OBJECT)
	$(info [ OK ] Building executable file)
	

# The rule to compile all files
# Dependencies:
# - create all necessary folders
# - needs the library file
build_executable: create_folders $(APP_DIR)/$(TARGET)


# The rule to create the output folders
create_folders:
	$(info        Creating output folders)
	@mkdir -p $(APP_DIR)
	@mkdir -p $(OBJ_DIR)
	$(info [ OK ] Creating output folders)


build_core_debug:
	$(info [    ] Build Core Debug)
	@$(MAKE) -C ../Core debug
	$(info [ OK ] Build Core Debug)

build_core_release:
	$(info [Drill CLI] Build Core Release)
	@$(MAKE) -C ../Core release

# The rule to build as debug adds some arguments before building normally
# adds DEBUG define and g (debug symbols)
debug: CXXFLAGS += -DDEBUG -g
debug: build_core_debug build_executable
	$(info [Drill CLI] debug version built)


# The rule to build as release adds some arguments before building normally
# adds NDEBUG define and O2 optimization
release: CXXFLAGS += -O2 -DNDEBUG
release: build_core_release build_executable
	$(info [Drill CLI] release version built)


# Cleans all produced files
clean:
	$(info [Drill CLI] cleaning all files...)
	@rm -rvf $(OBJ_DIR)/*
	@rm -rvf $(APP_DIR)/*
	$(info [Drill CLI] cleaning all files... OK)