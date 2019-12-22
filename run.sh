#!/bin/bash

pktsize=1500
num_of_spine=16
num_of_tor=9
num_of_nodes=144
nodes_per_rack=16
delay=1200 #propagation delay per hop (ns)

declare -a workload=("aditya" "dctcp" "datamining")

for workload in "${workload[@]}"
do
    for bandwidth in 10 40 100
    do
        for load in 0.2 0.4 0.6 0.8
        do
            echo "./ns scripts/large-scale-leaf-spine.tcl ${workload} ${load} ${bandwidth} ${delay} ${num_of_spine} ${num_of_tor} ${num_of_nodes}"
            ./ns scripts/large-scale-leaf-spine.tcl ${workload} ${load} ${bandwidth} ${delay} ${num_of_spine} ${num_of_tor} ${num_of_nodes}
            echo "python scripts/slowdown.py ${workload} ${load} ${bandwidth} ${pktsize} ${nodes_per_rack} ${delay}"
            python scripts/slowdown.py ${workload} ${load} ${bandwidth} ${pktsize} ${nodes_per_rack} ${delay}
            echo "python scripts/create_trace.py ${workload} ${load} ${bandwidth}"
            python scripts/create_trace.py ${workload} ${load} ${bandwidth}
        done
    done
done
