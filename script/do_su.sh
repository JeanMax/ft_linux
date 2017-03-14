#!/bin/bash

test "$1" && echo "$1" | sudo su - lfs
