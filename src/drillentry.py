import os
from os import DirEntry


from heuristics import is_in_system_dirs
from utils import human_readable
import datetime

from heuristics import is_in_english_dictionary, is_any_token_in_english_dictionary

from utils import get_file_icon
class DrillEntry:
    def __init__(self, fullpath: str):
      
       
        if not isinstance(fullpath, str):
            raise TypeError("fullpath must be a string")
        self.path = fullpath
        self.name = os.path.basename(fullpath) if len(fullpath) > 1 else fullpath  # / is a special case
            
        self._is_hidden = None
        self._is_dir = None
        self._is_file = None
        
        self._qicon = None
        self.containing_folder = os.path.dirname(fullpath)
  
        try:
            self.is_symlink = os.path.islink(fullpath)
        except Exception:
            self.is_symlink = False
            
        # Icon should be loaded on the worker side that creates the DrillEntry
        self._qicon = get_file_icon(self.path)
        
        self.formatted_time = "?"
        self.id = fullpath
        self.size = "?"
        self.modified_time = "?"
        try:
            stat = os.stat(fullpath)
            
            try:
                self.id = (stat.st_dev, stat.st_ino)
            except Exception:
                pass
            
            try:
                byte_size = stat.st_size
                if byte_size == 0 and self.is_dir: 
                    self.size = ""
                else:
                    self.size = human_readable(byte_size)
            except Exception:
                pass
                
            try:
                self.modified_time = stat.st_mtime
                if not self.is_symlink:
                    mod_time = datetime.datetime.fromtimestamp(self.modified_time)
                    self.formatted_time = mod_time.strftime('%Y/%m/%d %H:%M:%S')
                                    
            except Exception:
                pass
            
        except Exception:
            pass
            
    @property
    def qicon(self):
        return self._qicon
         
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
                self._is_hidden = self.name.startswith(".") or self.name.endswith("~") or self.name.endswith(".app") or is_in_system_dirs(self.path)
                # Check Windows hidden attribute
                if not self._is_hidden and os.name == 'nt':
                    attrs = os.stat(self.path).st_file_attributes
                    self._is_hidden = bool(attrs & (os.stat.FILE_ATTRIBUTE_HIDDEN | os.stat.FILE_ATTRIBUTE_SYSTEM))
            except Exception:
                self._is_hidden = False
        return self._is_hidden
            
    def __eq__(self, other):
        return self.id == other.id
        
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

        self_dict = is_in_english_dictionary(self.name.lower())
        other_dict = is_in_english_dictionary(other.name.lower())
        if self_dict and not other_dict:
            return True
        if not self_dict and other_dict:
            return False
           
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
