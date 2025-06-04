import os
from os import DirEntry

class DrillEntry:
    def __init__(self, fullpath):
      
        self.name = os.path.basename(fullpath) if len(fullpath) > 1 else fullpath  # / is a special case
        self.path = fullpath
            
        try:
            self.is_dir = os.path.isdir(fullpath)
        except Exception:
            self.is_dir = False
            
        try:
            self.is_file = os.path.isfile(fullpath)
        except Exception:
            self.is_file = False
            
        try:
            self.is_symlink = os.path.islink(fullpath)
        except Exception:
            self.is_symlink = False
        
        try:
            stat = os.stat(fullpath)
            
            try:
                self.size = stat.st_size
            except Exception:
                self.size = 0
                
            try:
                self.modified_time = stat.st_mtime
            except Exception:
                self.modified_time = 0
            
        except Exception:
            self.size = 0
            self.modified_time = 0
        
    def __eq__(self, other):
        return self.path == other.path
        
    def __repr__(self):
        return self.path
    
    def __str__(self):
        return self.path
    
    def __hash__(self):
        return hash(self.path)
    
    # def __lt__(self, other):
    #     pass