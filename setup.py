#!/usr/bin/env python3

from distutils.core import setup
import setuptools

setup(name='Drill',
      version='0.1.0rc3',
      description='Search files without using indexing, but clever crawling',
      author='Federico Santamorena',
      author_email='federico@santamorena.me',
      url='https://github.com/yatima1460/drill',
      install_requires=['psutil==5.6.2'],
     )