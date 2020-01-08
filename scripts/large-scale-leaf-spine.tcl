set ns [new Simulator]

#
# Flow configurations
#
set numFlow 10
set workload [lindex $argv 0] ;# cachefollower, mining, search, webserver, datamining, dctcp, aditya
set linkLoad [lindex $argv 1] ;# ranges from 0.0 to 1.0

#
# Toplogy configurations
#
set linkRate [lindex $argv 2] ;# Gb
set hostDelay 0.000000 ;# secs
set linkDelayHostTor [expr [lindex $argv 3]/1e9] ;# secs
set linkDelayTorAggr [expr [lindex $argv 3]/1e9] ;# secs
set dataBufferHost [expr (1000*1538)*(ceil(double($linkRate)/10.0))] ;# bytes / port
set dataBufferFromTorToAggr [expr 250*1538*(ceil(double($linkRate)/10.0))] ;# bytes / port
set dataBufferFromAggrToTor [expr 250*1538*(ceil(double($linkRate)/10.0))] ;# bytes / port
set dataBufferFromTorToHost [expr 250*1538*(ceil(double($linkRate)/10.0))] ;# bytes / port

set numAggr [lindex $argv 4] ;# number of aggregator switches
set numTor [lindex $argv 5] ;# number of ToR switches
set numNode [lindex $argv 6] ;# number of nodes

#
# XPass configurations
#
set alpha 0.5
set w_init 0.0625
set creditBuffer [expr 84*8]
set maxCreditBurst [expr 84*2]
set minJitter -0.1
set maxJitter 0.1
set minEthernetSize 84
set maxEthernetSize 1538
set minCreditSize 76
set maxCreditSize 92
set xpassHdrSize 78
set maxPayload [expr $maxEthernetSize-$xpassHdrSize]
set avgCreditSize [expr ($minCreditSize+$maxCreditSize)/2.0]
set creditBW [expr $linkRate*125000000*$avgCreditSize/($avgCreditSize+$maxEthernetSize)]
set creditBW [expr int($creditBW)]

#
# Simulation setup
#
set simStartTime 0.1
set simEndTime 60

# Output file
file mkdir "outputs"
set nt [open "outputs/trace.out" w]
set fct_out [open "outputs/fct.out" w]
set wst_out [open "outputs/waste.out" w]
puts $fct_out "Flow ID,Flow Size(bytes),Flow Start Time(secs),Flow Completion Time(secs),Throughput(Gbps)"
puts $wst_out "Flow ID,Flow Size(bytes),Wasted Credit"
close $fct_out
close $wst_out

set flowfile [open flowfile.tr w]

proc finish {} {
  global ns nt flowfile
  $ns flush-trace
  close $nt
  #close $flowfile
  puts "Simulation terminated successfully."
  exit 0
}
#$ns trace-all $nt

# Basic parameter settings
Agent/XPass set min_credit_size_ $minCreditSize
Agent/XPass set max_credit_size_ $maxCreditSize
Agent/XPass set min_ethernet_size_ $minEthernetSize
Agent/XPass set max_ethernet_size_ $maxEthernetSize
Agent/XPass set max_credit_rate_ $creditBW
Agent/XPass set alpha_ $alpha
Agent/XPass set target_loss_scaling_ 0.125
Agent/XPass set w_init_ $w_init
Agent/XPass set min_w_ 0.01
Agent/XPass set retransmit_timeout_ 0.0001
Agent/XPass set min_jitter_ $minJitter
Agent/XPass set max_jitter_ $maxJitter

Queue/XPassDropTail set credit_limit_ $creditBuffer
Queue/XPassDropTail set max_tokens_ $maxCreditBurst
Queue/XPassDropTail set token_refresh_rate_ $creditBW

DelayLink set avoidReordering_ true
$ns rtproto DV
Agent/rtProto/DV set advertInterval 10
Node set multiPath_ 1
Classifier/MultiPath set symmetric_ true
Classifier/MultiPath set nodetype_ 0

# Workloads setting
if {[string compare $workload "mining"] == 0} {
  set workloadPath "workloads/workload_mining.tcl"
  set avgFlowSize 7410212
} elseif {[string compare $workload "search"] == 0} {
  set workloadPath "workloads/workload_search.tcl"
  set avgFlowSize 1654275
} elseif {[string compare $workload "cachefollower"] == 0} {
  set workloadPath "workloads/workload_cachefollower.tcl"
  set avgFlowSize 701490
} elseif {[string compare $workload "webserver"] == 0} {
  set workloadPath "workloads/workload_webserver.tcl"
  set avgFlowSize 63735
} elseif {[string compare $workload "dctcp"] == 0} {
  set workloadPath "workloads/workload_dctcp.tcl"
  set avgFlowSize 988530
} elseif {[string compare $workload "aditya"] == 0} {
  set workloadPath "workloads/workload_aditya.tcl"
  set avgFlowSize 124500
} elseif {[string compare $workload "datamining"] == 0} {
  set workloadPath "workloads/workload_datamining.tcl"
  set avgFlowSize 1149000
} else {
  puts "Invalid workload: $workload"
  exit 0
}

set overSubscRatio [expr double($numNode/$numTor)/double($numAggr)]
set lambda [expr ($numNode*$linkRate*1000000000*$linkLoad)/($avgFlowSize*8.0/$maxPayload*$maxEthernetSize)]
set avgFlowInterval [expr $overSubscRatio/$lambda]

# Random number generators
set RNGFlowSize [new RNG]
$RNGFlowSize seed 61569011

set RNGFlowInterval [new RNG]
$RNGFlowInterval seed 94762103

set RNGSrcNodeId [new RNG]
$RNGSrcNodeId seed 17391005

set RNGDstNodeId [new RNG]
$RNGDstNodeId seed 35010256

set randomFlowSize [new RandomVariable/Empirical]
$randomFlowSize use-rng $RNGFlowSize
$randomFlowSize set interpolation_ 2
$randomFlowSize loadCDF $workloadPath

set randomFlowInterval [new RandomVariable/Exponential]
$randomFlowInterval use-rng $RNGFlowInterval
$randomFlowInterval set avg_ $avgFlowInterval

set randomSrcNodeId [new RandomVariable/Uniform]
$randomSrcNodeId use-rng $RNGSrcNodeId
$randomSrcNodeId set min_ 0
$randomSrcNodeId set max_ $numNode

set randomDstNodeId [new RandomVariable/Uniform]
$randomDstNodeId use-rng $RNGDstNodeId
$randomDstNodeId set min_ 0
$randomDstNodeId set max_ $numNode

# Node
puts "Creating nodes..."
for {set i 0} {$i < $numNode} {incr i} {
  set dcNode($i) [$ns node]
  $dcNode($i) set nodetype_ 1
}
for {set i 0} {$i < $numTor} {incr i} {
  set dcTor($i) [$ns node]
  $dcTor($i) set nodetype_ 2
}
for {set i 0} {$i < $numAggr} {incr i} {
  set dcAggr($i) [$ns node]
  $dcAggr($i) set nodetype_ 3
}

# Link
puts "Creating links..."
for {set i 0} {$i < $numTor} {incr i} {
  for {set j 0} {$j < $numAggr} {incr j} {
    $ns simplex-link $dcTor($i) $dcAggr($j) [set linkRate]Gb $linkDelayTorAggr XPassDropTail
    set link_tor_aggr [$ns link $dcTor($i) $dcAggr($j)]
    set queue_tor_aggr [$link_tor_aggr queue]
    $queue_tor_aggr set data_limit_ $dataBufferFromTorToAggr

    $ns simplex-link $dcAggr($j) $dcTor($i) [set linkRate]Gb $linkDelayTorAggr XPassDropTail
    set link_aggr_tor [$ns link $dcAggr($j) $dcTor($i)]
    set queue_aggr_tor [$link_aggr_tor queue]
    $queue_aggr_tor set data_limit_ $dataBufferFromAggrToTor
  }
}

for {set i 0} {$i < $numNode} {incr i} {
  set torIndex [expr $i/($numNode/$numTor)]

  $ns simplex-link $dcNode($i) $dcTor($torIndex) [set linkRate]Gb [expr $linkDelayHostTor+$hostDelay] XPassDropTail
  set link_host_tor [$ns link $dcNode($i) $dcTor($torIndex)]
  set queue_host_tor [$link_host_tor queue]
  $queue_host_tor set data_limit_ $dataBufferHost

  $ns simplex-link $dcTor($torIndex) $dcNode($i) [set linkRate]Gb $linkDelayHostTor XPassDropTail
  set link_tor_host [$ns link $dcTor($torIndex) $dcNode($i)]
  set queue_tor_host [$link_tor_host queue]
  $queue_tor_host set data_limit_ $dataBufferFromTorToHost
}

puts "Creating agents and flows..."
set fp [open [lindex $argv 7] r]
set file_data [read $fp]
set data [split $file_data "\n"]
set linecount 0
foreach line $data {
    set token [split $line ","]
    set count 0
    set id 0
    set src 0
    set dst 0
    set size 0
    set starttime 0
    foreach t $token {
        if {$count == 0} {
            set id $t
        } elseif {$count == 1} {
            set src $t
        } elseif {$count == 2} {
            set dst $t
        } elseif {$count == 3} {
            set size $t
        } elseif {$count == 4} {
            set starttime $t
        }
        set count [expr $count+1]

        set sender($id) [new Agent/XPass]
        set receiver($id) [new Agent/XPass]

        $sender($id) set fid_ $id
        $sender($id) set host_id_ $src
        $receiver($id) set fid_ $id
        $receiver($id) set host_id_ $dst

        $ns attach-agent $dcNode($src) $sender($id)
        $ns attach-agent $dcNode($dst) $receiver($id)

        $ns connect $sender($id) $receiver($id)

        set srcIndex($id) $src
        set dstIndex($id) $dst
        set flowsize($id) $size
        set flowstart($id) $starttime

        $ns at $simEndTime "$sender($id) close"
        $ns at $simEndTime "$receiver($id) close"
    }

    #puts "$id $src $dst $size $starttime"

    set linecount [expr $linecount+1]
    if {$linecount == $numFlow} {
    #    set simEndTime [expr $simStartTime+$starttime]
        break
    }
}

close $fp

set nextTime $simStartTime
set fidx 0

proc sendBytes {} {
  global ns simStartTime nextTime sender fidx numFlow srcIndex dstIndex flowsize flowstart flowfile randomFlowInterval

  puts $flowfile "$nextTime $fidx $srcIndex($fidx) $dstIndex($fidx) $flowsize($fidx)"
  #puts "$fidx $srcIndex($fidx) $dstIndex($fidx) $flowsize($fidx) $nextTime"
  $ns at $nextTime "$sender($fidx) advance-bytes $flowsize($fidx)"

  set fidx [expr $fidx+1]

  if {$fidx < $numFlow} {
    set nextTime [expr $simStartTime+$flowstart($fidx)]
    $ns at $nextTime "sendBytes"
  }
}

$ns at 0.0 "puts \"Simulation starts!\""
$ns at $nextTime "sendBytes"
$ns at [expr $simEndTime+1] "finish"
$ns run
