import sys

cdf = []

f = open("workloads/workload_imc.tcl", "r")

for line in f:
    tokens = line.split()
    cdf.append([float(tokens[0]), float(tokens[2])])
f.close()

print cdf

avg = 0
for i in range(1,len(cdf)):
    print cdf[i-1][0], (cdf[i][1]-cdf[i-1][1])
    avg += cdf[i-1][0]*(cdf[i][1]-cdf[i-1][1])
print avg
