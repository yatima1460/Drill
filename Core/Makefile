CXX      := c++
CXXFLAGS :=                  \
			-pedantic-errors \
			-Wall 			 \
			-Wextra 		 \
			-std=c++17       \
			-Wconversion	 \
			-c # Compile without linking, this needs to be a library not an executable


# Name of the build directory
BUILD    := ./Build

# Name of the directory for temporary object files
OBJ_DIR  := $(BUILD)/Objects

# Name of the directory for library file
APP_DIR  := $(BUILD)/Library

# Name of the library
TARGET   := libDrillCore.a

# Headers to include
INCLUDE  := -Iinclude/ -Ispdlog/include/

# Source files
SRC      :=                      	\
   $(wildcard ./*.cpp) 				\
   $(wildcard Subsystem/Linux.cpp)

# Variable holding all object files
OBJECTS := $(SRC:%.cpp=$(OBJ_DIR)/%.o)

$(info ========== [Drill Core] ==========)

# We tell make that the rules with these names are not real files but just commands to execute
.PHONY: build_library create_folders debug release clean

# The rule to compile all files
# Dependencies:
# - create all necessary folders
# - needs the library file
build_library: create_folders $(APP_DIR)/$(TARGET)

# The rule to create object files: needs .cpp files
$(OBJ_DIR)/%.o: %.cpp
	$(info [Drill Core] building object file '$@')
	@mkdir -p $(@D)
	@$(CXX) $(CXXFLAGS) $(INCLUDE) -o $@ -c $<
	
# The rule to create the single library file
# Dependencies:
# - needs all object files
$(APP_DIR)/$(TARGET): $(OBJECTS)
	$(info [Drill Core] building library file $(APP_DIR)/$(TARGET))
	@mkdir -p $(@D)
	@$(AR) rs $(APP_DIR)/$(TARGET) $(OBJECTS)

#@$(CXX) $(CXXFLAGS) $(INCLUDE) -o $(APP_DIR)/$(TARGET) $(OBJECTS)
#cd spdlog && $(MAKE)

# The rule to create the output folders
create_folders:
	$(info [Drill Core] creating output folders)
	@mkdir -p $(APP_DIR)
	@mkdir -p $(OBJ_DIR)

# The rule to build as debug adds some arguments before building normally
# adds DEBUG define and g (debug symbols)
debug: CXXFLAGS += -DDEBUG -g
debug: build_library
	$(info [Drill Core] building debug done)

# The rule to build as release adds some arguments before building normally
# adds NDEBUG define and O2 optimization
release: CXXFLAGS += -O2 -DNDEBUG
release: build_library
	$(info [Drill Core] building release done)

# Cleans all produced files
clean:
	$(info [Drill Core] cleaning all files)
	@rm -rf $(BUILD)