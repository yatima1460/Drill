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
        self._sort_key = None
        
        # Icon loading is deferred to qicon property - must happen on UI thread
        self._qicon = None
        self.containing_folder = os.path.dirname(fullpath)
  
        try:
            self.is_symlink = os.path.islink(fullpath)
        except Exception:
            self.is_symlink = False
        
        self.formatted_time = "?"
        self.id = os.path.normcase(os.path.abspath(fullpath))
        self.size = "?"
        self.modified_time = 0.0
        try:
            stat = os.stat(fullpath)
            
            try:
                # On Windows, st_ino is not guaranteed to be unique, 
                # but (dev, ino) is still useful for detecting hard links/junctions on NTFS.
                # However, for our purposes, the normalized path is usually enough 
                # since we skip symlinks to avoid loops.
                if os.name != 'nt':
                    if stat.st_ino != 0:
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
        # Icons MUST be loaded on the UI thread - Qt GUI objects are not thread-safe
        # This property is accessed from main.py when adding items to the tree widget
        if self._qicon is None:
            self._qicon = get_file_icon(self.path)
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
        return self.sort_key < other.sort_key

    @property
    def sort_key(self):
        if self._sort_key is None:
            # Memoized ordering key used by search queue sorting.
            # Lower values mean higher priority.
            self_dict = is_in_english_dictionary(self.name.lower())
            self_slashes = self.path.count(os.sep)
            self_length = len(self.path)
            self._sort_key = (
                0 if self_dict else 1,
                0 if not self.is_hidden else 1,
                self_slashes,
                self_length,
                -self.modified_time,
                self.path,
            )
        return self._sort_key
