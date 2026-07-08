export PATH="/home/bqhung/Application/oss-cad-suite/bin:$PATH"

iverilog -g2012 -t null Memory/*.sv  Memory/*.v  *.sv
