# search.py
import os
import queue
from heuristics import get_root_directories
import unicodedata
from PyQt6.QtWidgets import QFileIconProvider
from PyQt6.QtCore import QFileInfo
import logging
from typing import Optional, Tuple, List
from concurrent.futures import ThreadPoolExecutor, Future
import threading

SearchResult = Tuple[str, str, str, str, bool]

import ctypes

def can_access_directory(path):
    #FIXME: not working on Windows
    return os.access(path, os.R_OK | os.X_OK)

def get_icon_for_path(file_path: str):
    """Returns the system-native icon for a file/directory path."""
    try:
        
        file_info = QFileInfo(file_path)
        
        icon_provider = QFileIconProvider()
        
        # Handle .app bundles (macOS applications)
        
        if file_path.endswith(".app") and file_info.isDir():
            logging.debug(f"Detected macOS application bundle: {file_path}")
            return None
        
        # Fallback for other files/directories
        return icon_provider.icon(file_info)
    except BaseException as e:
        logging.error(f"Error getting icon for {file_path}: {e}")
        return None

def normalize_text(text):
    # Normalize to NFD and remove diacritics (accents)
    normalized = unicodedata.normalize('NFD', text)
    return ''.join(c for c in normalized if unicodedata.category(c) != 'Mn')


def human_readable(size, suffix='B'):
    # Uses KB, MB, GB, TB, etc. (not KiB, MiB...)
    units = ['', 'K', 'M', 'G', 'T', 'P', 'E', 'Z']
    if 0 < abs(size) < 1024:
        # For any nonzero value less than 1024, show as "1 KB"
        return "1 KB"
    elif size == 0:
        return "Empty"
    for unit in units:
        if abs(size) < 1024.0:
            return f"{size:3.0f} {unit}{suffix}"
        size /= 1024.0
    return f"{size:.1f} Y{suffix}"

import difflib

def token_search(filename, search_text, fuzzy):
    # Normalize and tokenize the search text
    search_text_tokens = normalize_text(search_text.lower()).split(" ")
    filename = normalize_text(filename.lower())
    if not fuzzy:
        # Exact match for each token
        result = True
        for token in search_text_tokens:
            if token not in filename:
                result = False
                break
        return result
    else:
        # Fuzzy match: token is similar to any word in filename
        filename_tokens = filename.split()
        for token in search_text_tokens:
            # Find the closest match in filename tokens
            matches = difflib.get_close_matches(token, filename_tokens, n=1, cutoff=0.5)
            if not matches:
                return False
        return True
    
import datetime
import multiprocessing
from queue import PriorityQueue, Queue
import time
            
def worker(dir_queue: Queue, result_queue: Queue, running: threading.Event, search_text: str, roots: set[str], fuzzy: bool, maximum_depth):
    
    logger = logging.getLogger("Worker")
    # logger.setLevel(logging.INFO)
    handler = logging.StreamHandler()
    formatter = logging.Formatter('[%(threadName)s][%(levelname)s]: %(message)s')
    handler.setFormatter(formatter)
    if not logger.handlers:
        logger.addHandler(handler)
    logger.propagate = False
    while running.is_set():
        try:

            current_dir = dir_queue.get()

            sep_count = current_dir.count(os.sep)
            if sep_count > maximum_depth[0]:
                maximum_depth[0] = sep_count
                logger.info(f"Longest path updated: {current_dir} (separators: {sep_count})")
        except queue.Empty:
            logger.warning("No directories to process, worker is waiting...")
            # TODO: fix this? basically the idea is that if we encounter a very slow disk we should not kill workers
            time.sleep(0.1)
        try:
            #FIXME: except InterruptedError
            with os.scandir(current_dir) as it:
                for entry in it:
                    if not running.is_set(): 
                        break
                    
                   
                        
                    # Check if the entry is a symlink    
                    #icon = get_icon_for_path(entry.path)
                    #if icon is None:
                    try:
                        is_dir = entry.is_dir(follow_symlinks=False)
                    except OSError:
                        logger.info(f"Cannot determine if {entry.path} is a directory")
                        is_dir = False
                    if is_dir:
                        
                        subdirectory = entry.path
                        
                        if not can_access_directory(subdirectory):
                            logger.debug(f"Cannot access directory: {subdirectory} - skipping")
                            continue
                        if not os.path.exists(subdirectory):
                            logger.warning(f"Directory does not exist: {subdirectory} - skipping")
                            continue

                        # the idea is to treat roots just like symlinks
                        if entry.path in roots:
                            logger.info("Skipping root directory: %s", subdirectory)
                            continue
                        # add beginning of queue if matches token search otherwise add to end
                  
                        dir_queue.put(entry.path)
                        

                        # if subdirectory not in visited:
                        #     dir_queue.put(entry.path)                  
                        #     visited.add(subdirectory)
                    #elif entry.is_file(follow_symlinks=False):
                    #FIXME: roots are not being added to search results
                    #FIXME: ⁉️ emoji not appearing
                    if token_search(entry.name, search_text, fuzzy):
                        
                        # Check if the file is a symlink
                        
                        formatted_time = "?"
                        size = "?"
                        if not entry.is_symlink():
                            stat = entry.stat()
                            mod_time = datetime.datetime.fromtimestamp(stat.st_mtime)
                            formatted_time = mod_time.strftime('%Y/%m/%d %H:%M:%S')
                            size = stat.st_size
                            if size == 0 and is_dir: 
                                size = ""
                            else:
                                size = human_readable(size)

                        
                        result_queue.put((
                            entry.name,
                            current_dir,
                            size,
                            formatted_time,
                            is_dir
                        ))
        except KeyboardInterrupt:
            logger.info("Keyboard interrupt detected, stopping...")
            break
        except BaseException as e:
            logger.exception(f"crashed scanning {current_dir} - recovering... - {e}")
    logger.info("exited")

class Search:
    def __init__(self, search_text):
        logging.basicConfig(level=logging.INFO, format='[%(processName)s][%(levelname)s]: %(message)s')
        if search_text is None or search_text == "":
            raise ValueError("Input string must not be None or empty")   
        self.search_text = search_text
        self.items: list[list[str]] = []
        self.executor = ThreadPoolExecutor(thread_name_prefix="SearchWorker")
        self.dir_queue = queue.Queue()
        self.result_queue = queue.Queue()
        self.running = threading.Event()
        self.processes: List[Future] = []
        logging.info("Search init %s", self.search_text)
        multiprocessing.current_process().name = "UI"
        if search_text.startswith("fuzzy:"):
            self.search_text = search_text[6:]
            logging.info("Fuzzy search %s", self.search_text)
            self.fuzzy = True
        else:
            self.fuzzy = False

    def start(self):
        logging.info("Search started")
        self.running.set()


        self.roots = get_root_directories()

        # Initialize directory queue
        if os.name == 'nt':
            drives = [f"{d}:\\" for d in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' if os.path.exists(f"{d}:\\")]
            for drive in drives:
                self.dir_queue.put(drive)
        else:
            # Add all self.roots to the queue
            for root in self.roots:
                if os.path.exists(root):
                    self.dir_queue.put(root)
                else:
                    logging.warning(f"Root path does not exist: {root}")
        
        self.maximum_depth = [0] 

        # Start workers
        cpu_count = self.executor._max_workers
        for i in range(cpu_count):
            p = self.executor.submit(worker, self.dir_queue, self.result_queue, self.running, self.search_text, self.roots, self.fuzzy, self.maximum_depth)
            #p.name = f"Worker-{i}"
            logging.info("Created worker %s",p)
            self.processes.append(p)

    def poll_results(self):
        while not self.result_queue.empty():
            self.items.append(self.result_queue.get())

    def stop(self):
        '''
        Stop the search asynchronously.
        Keep in mind that you should stop any kind of UI update before calling this method.
        '''
        logging.info("Asked to stop search")
        self.running.clear()
        logging.info("Set running event to False")
        self.dir_queue = queue.Queue()
        logging.info("Cleared directory queue")
        self.executor.shutdown(wait=False, cancel_futures=True)
        logging.info("Executor shutdown initiated")

    def pop_result(self) -> Optional[SearchResult]:
        try:
            return self.result_queue.get(block=False)
        except queue.Empty:
            return None
    
    def processes_count(self):
        return len(self.processes)
    
    def total_to_scan(self):
        return self.dir_queue.qsize()
    
    def get_longest_path(self):
        current_longest = self.maximum_depth[0]
        return current_longest
    
    def is_done(self):
        for p in self.processes:
            if not p.done():
                return False
        return True
        