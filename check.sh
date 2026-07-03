#!/bin/bash

source /home/thh/oss-cad-suite/environment

iverilog -g2012 -t null *.v *.sv
