import sys

workload = sys.argv[1]
load = float(sys.argv[2])
bandwidth = int(sys.argv[3])

folder = "all-to-all-144-"+workload
filename = "trace-"+str(bandwidth)+"G-"+str(load)+".csv"

f = open("flowfile.tr", "r")
out = open(folder+"/"+filename, "w")

for line in f:
    tokens = line.split()
    starttime = float(tokens[0].strip()) - 0.1
    assert(starttime >= 0)
    out.write(tokens[1].strip()+","+tokens[2].strip()+","+tokens[3].strip()+","+tokens[4].strip()+","+str(starttime))
    out.write("\n")

f.close()
out.close()
