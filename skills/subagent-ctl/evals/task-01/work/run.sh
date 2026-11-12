#!/bin/sh
cd "$(dirname "$0")" && python3 -m unittest discover -q -p 'test_*.py'
