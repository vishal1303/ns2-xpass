#!/bin/bash

pktsize=1500
num_of_spine=16
num_of_tor=9
num_of_nodes=144
nodes_per_rack=16

declare -a workload=("aditya" "dctcp")

for workload in "${workload[@]}"
do
    for bandwidth in 40 100 400
    do
        for delay in 625.6 #propagation delay per hop (ns)
        do
            for load in 0.2 0.4 0.6 0.8
            do
                echo "./ns scripts/large-scale-leaf-spine.tcl ${workload} ${load} ${bandwidth} ${delay} ${num_of_spine} ${num_of_tor} ${num_of_nodes} workload/dc_workload/all-to-all-144-${workload}/trace-${bandwidth}G-${load}.csv"
                ./ns scripts/large-scale-leaf-spine.tcl ${workload} ${load} ${bandwidth} ${delay} ${num_of_spine} ${num_of_tor} ${num_of_nodes} workload/dc_workload/all-to-all-144-${workload}/trace-${bandwidth}G-${load}.csv
                echo "python scripts/slowdown.py ${workload} ${load} ${bandwidth} ${pktsize} ${nodes_per_rack} ${delay}"
                python scripts/slowdown.py ${workload} ${load} ${bandwidth} ${pktsize} ${nodes_per_rack} ${delay}
            done
        done
    done
done
