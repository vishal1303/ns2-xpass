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
set dataBufferHost [expr 1000*1538] ;# bytes / port
set dataBufferFromTorToAggr [expr 250*1538] ;# bytes / port
set dataBufferFromAggrToTor [expr 250*1538] ;# bytes / port
set dataBufferFromTorToHost [expr 250*1538] ;# bytes / port

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
  close $flowfile
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
for {set i 0} {$i < $numFlow} {incr i} {
  set src_nodeid [expr int([$randomSrcNodeId value])]
  set dst_nodeid [expr int([$randomDstNodeId value])]

  while {$src_nodeid == $dst_nodeid} {
#    set src_nodeid [expr int([$randomSrcNodeId value])]
    set dst_nodeid [expr int([$randomDstNodeId value])]
  }

  set sender($i) [new Agent/XPass]
  set receiver($i) [new Agent/XPass]

  $sender($i) set fid_ $i
  $sender($i) set host_id_ $src_nodeid
  $receiver($i) set fid_ $i
  $receiver($i) set host_id_ $dst_nodeid

  $ns attach-agent $dcNode($src_nodeid) $sender($i)
  $ns attach-agent $dcNode($dst_nodeid) $receiver($i)

  $ns connect $sender($i) $receiver($i)

  $ns at $simEndTime "$sender($i) close"
  $ns at $simEndTime "$receiver($i) close"

  set srcIndex($i) $src_nodeid
  set dstIndex($i) $dst_nodeid
}

set nextTime $simStartTime
set fidx 0

proc sendBytes {} {
  global ns random_flow_size nextTime sender fidx randomFlowSize randomFlowInterval numFlow srcIndex dstIndex flowfile
  while {1} {
    set fsize [expr ceil([expr [$randomFlowSize value]])]
    if {$fsize > 0} {
      break;
    }
  }

  puts $flowfile "$nextTime $fidx $srcIndex($fidx) $dstIndex($fidx) $fsize"
  #puts "$nextTime $fidx $srcIndex($fidx) $dstIndex($fidx) $fsize"
  $ns at $nextTime "$sender($fidx) advance-bytes $fsize"

  set nextTime [expr $nextTime+[$randomFlowInterval value]]
  set fidx [expr $fidx+1]

  if {$fidx < $numFlow} {
    $ns at $nextTime "sendBytes"
  } elseif {$fidx == $numFlow} {
      $ns flush-trace
      close $flowfile
  }
}

$ns at 0.0 "puts \"Simulation starts!\""
$ns at $nextTime "sendBytes"
$ns at [expr $simEndTime+1] "finish"
$ns run
