import os
from os import DirEntry


from heuristics import is_in_system_dirs
from utils import human_readable
import datetime

class DrillEntry:
    def __init__(self, fullpath: str):
      
       
        if not isinstance(fullpath, str):
            raise TypeError("fullpath must be a string")
        self.path = fullpath
        self.name = os.path.basename(fullpath) if len(fullpath) > 1 else fullpath  # / is a special case
            
        self._is_hidden = None
        self._is_dir = None
        self._is_file = None
  
        try:
            self.is_symlink = os.path.islink(fullpath)
        except Exception:
            self.is_symlink = False
        
        self.formatted_time = "?"
        try:
            stat = os.stat(fullpath)
            
            try:
                self.size = stat.st_size
                if self.size == 0 and self.is_dir: 
                    self.size = ""
                else:
                    self.size = human_readable(self.size)
            except Exception:
                self.size = "?"
                
            try:
                self.modified_time = stat.st_mtime
                if not self.is_symlink:
                    mod_time = datetime.datetime.fromtimestamp(self.modified_time)
                    self.formatted_time = mod_time.strftime('%Y/%m/%d %H:%M:%S')
                           
                        
            except Exception:
                self.modified_time = "?"
            
        except Exception:
            self.size = "?"
            self.modified_time = "?"
         
    @property   
    def is_dir(self):
        if self._is_dir is None:
            try:
                self._is_dir = os.path.isdir(self.path)
            except Exception:
                self._is_dir = False
        return self._is_dir
    
    @property
    def is_file(self):
        if self._is_file is None:
            try:
                self._is_file = os.path.isfile(self.path)
            except Exception:
                self._is_file = False
                
    @property
    def is_hidden(self):
        if self._is_hidden is None:
            try:
                self._is_hidden = self.name.startswith(".") or self.name.endswith("~") or self.name.endswith(".app") or is_in_system_dirs(fullpath)
                # Check Windows hidden attribute
                if not self._is_hidden and os.name == 'nt':
                    attrs = os.stat(self.path).st_file_attributes
                    self._is_hidden = bool(attrs & (os.stat.FILE_ATTRIBUTE_HIDDEN | os.stat.FILE_ATTRIBUTE_SYSTEM))
            except Exception:
                self._is_hidden = False
        return self._is_hidden
            
    def __eq__(self, other):
        return self.path == other.path
        
    def __repr__(self):
        return self.path
    
    def __str__(self):
        return self.path
    
    def __hash__(self):
        return hash(self.path)
    
    def __lt__(self, other) -> bool:
        '''
        Returns True if this entry is more important than the other entry.
        '''

           
        # Regular folders should come first
        if self.is_hidden and not other.is_hidden:
            return False
        if not self.is_hidden and other.is_hidden:
            return True

        # Less importance to folders deep in the hierarchy
        self_slashes = self.path.count(os.sep)
        other_slashes = other.path.count(os.sep)
        if self_slashes != other_slashes:
            return self_slashes < other_slashes
     
        # Less importance to folders with an overall longer path
        self_length = len(self.path)
        other_length = len(other.path)
        if self_length != other_length:
            return self_length < other_length
        
        # NOTE: using the date is very bad heuristics,
        # Drill will get lost into a sea of recent folders created often automatically by applications.
        # So this should be one of the last heuristics
        # Only useful to break ties as a last resort
        #
        # Between two regular folders most recently modified folders should come first
        if self.modified_time != other.modified_time:
            return self.modified_time > other.modified_time

        return False
