set ns [new Simulator]

set service1_senders 2;	#highes priority
set service2_senders 8;
set service3_senders 2;
set service1_rate_mbps 4000
set service1_id 0
set service2_id 1
set service3_id 2
set K 80;	#ECN marking threshold
set K_0 $K
set K_1 $K
set K_2 $K
set W_1 1500;
set W_2 4500;
set marking_scheme 4

set RTT 0.0001
set DCTCP_g_ 0.0625
set ackRatio 1
set packetSize 1460
set lineRate 10Gb

set simulationTime 0.02
set throughputSamplingInterval 0.0002

Agent/TCP set windowInit_ 10
Agent/TCP set ecn_ 1
Agent/TCP set old_ecn_ 1
Agent/TCP set dctcp_ false
Agent/TCP set dctcp_g_ $DCTCP_g_
Agent/TCP set packetSize_ $packetSize
Agent/TCP set window_ 1256
Agent/TCP set slow_start_restart_ false
Agent/TCP set minrto_ 0.01 ; # minRTO = 10ms
Agent/TCP set windowOption_ 0
Agent/TCP/FullTcp set segsize_ $packetSize
Agent/TCP/FullTcp set segsperack_ $ackRatio;
Agent/TCP/FullTcp set spa_thresh_ 3000;
Agent/TCP/FullTcp set interval_ 0.04 ; #delayed ACK interval = 40ms
Agent/TCP/FullTcp set enable_pias_ false

Queue set limit_ 1000

Queue/PrioDwrr set prio_queue_num_ 1
Queue/PrioDwrr set dwrr_queue_num_ 2
Queue/PrioDwrr set mean_pktsize_ [expr $packetSize+40]
Queue/PrioDwrr set port_thresh_ $K
Queue/PrioDwrr set marking_scheme_ $marking_scheme
Queue/PrioDwrr set estimate_round_alpha_ 0.75
Queue/PrioDwrr set estimate_quantum_alpha_ 0.75
Queue/PrioDwrr set estimate_round_idle_interval_bytes_ 1500
Queue/PrioDwrr set estimate_quantum_interval_bytes_ 1500
Queue/PrioDwrr set estimate_quantum_enable_timer_ false
Queue/PrioDwrr set dq_thresh_ 10000
Queue/PrioDwrr set estimate_rate_alpha_ 0.875
Queue/PrioDwrr set link_capacity_ $lineRate
Queue/PrioDwrr set debug_ true

Queue/RED set bytes_ false
Queue/RED set queue_in_bytes_ true
Queue/RED set mean_pktsize_ [expr $packetSize+40]
Queue/RED set setbit_ true
Queue/RED set gentle_ false
Queue/RED set q_weight_ 1.0
Queue/RED set mark_p_ 1.0
Queue/RED set thresh_ $K
Queue/RED set maxthresh_ $K

set mytracefile [open mytracefile.tr w]
$ns trace-all $mytracefile
set throughputfile [open throughputfile.tr w]
set tot_qlenfile [open tot_qlenfile.tr w]
set qlenfile [open qlenfile.tr w]
set tracedir tcp_flows

proc finish {} {
	global ns mytracefile throughputfile qlenfile tot_qlenfile
	$ns flush-trace
	close $mytracefile
	close $throughputfile
	close $qlenfile
	exit 0
}

set switch [$ns node]
set receiver [$ns node]

$ns simplex-link $switch $receiver $lineRate [expr $RTT/4] PrioDwrr
$ns simplex-link $receiver $switch $lineRate [expr $RTT/4] DropTail

set L [$ns link $switch $receiver]
set q [$L set queue_]
$q set-quantum 1 $W_1
$q set-quantum 2 $W_2
$q set-thresh 0 $K_0
$q set-thresh 1 $K_1
$q set-thresh 2 $K_2
$q attach-total $tot_qlenfile
$q attach-queue $qlenfile

#Service type 1 senders
for {set i 0} {$i < $service1_senders} {incr i} {
	set n1($i) [$ns node]
    $ns duplex-link $n1($i) $switch $lineRate [expr $RTT/4] RED
	set tcp1($i) [new Agent/TCP/FullTcp/Sack]
	set sink1($i) [new Agent/TCP/FullTcp/Sack]
	$tcp1($i) set serviceid_ $service1_id
	$sink1($i) listen

	$ns attach-agent $n1($i) $tcp1($i)
    $ns attach-agent $receiver $sink1($i)
	$ns connect $tcp1($i) $sink1($i)

	set ftp1($i) [new Application/FTP]
	$ftp1($i) attach-agent $tcp1($i)
	$ftp1($i) set type_ FTP

	###Add token bucket rate limiter
	set tbf($i) [new TBF]
	$tbf($i) set bucket_ 64000
	$tbf($i) set rate_ [expr $service1_rate_mbps / $service1_senders]Mbit
	$tbf($i) set qlen_ 1000
	$ns attach-tbf-agent $n1($i) $tcp1($i) $tbf($i)

	$ns at [expr 0] "$ftp1($i) start"
}

#Service type 2 senders
for {set i 0} {$i < $service2_senders} {incr i} {
	set n2($i) [$ns node]
    $ns duplex-link $n2($i) $switch $lineRate [expr $RTT/4] RED
	set tcp2($i) [new Agent/TCP/FullTcp/Sack]
	set sink2($i) [new Agent/TCP/FullTcp/Sack]
	$tcp2($i) set serviceid_ $service2_id
	$sink2($i) listen

	$ns attach-agent $n2($i) $tcp2($i)
    $ns attach-agent $receiver $sink2($i)
	$ns connect $tcp2($i) $sink2($i)

	set ftp2($i) [new Application/FTP]
	$ftp2($i) attach-agent $tcp2($i)
	$ftp2($i) set type_ FTP

	$ns at [expr $simulationTime * 1 / 3] "$ftp2($i) start"
}

#Service type 3 senders
for {set i 0} {$i < $service3_senders} {incr i} {
	set n3($i) [$ns node]
    $ns duplex-link $n3($i) $switch $lineRate [expr $RTT/4] RED
	set tcp3($i) [new Agent/TCP/FullTcp/Sack]
	set sink3($i) [new Agent/TCP/FullTcp/Sack]
	$tcp3($i) set serviceid_ $service3_id
	$sink3($i) listen

	$ns attach-agent $n3($i) $tcp3($i)
    $ns attach-agent $receiver $sink3($i)
	$ns connect $tcp3($i) $sink3($i)

	set ftp3($i) [new Application/FTP]
	$ftp3($i) attach-agent $tcp3($i)
	$ftp3($i) set type_ FTP

	$ns at [expr $simulationTime * 2 / 3] "$ftp3($i) start"
}

proc record {} {
	global ns throughputfile throughputSamplingInterval service1_senders service2_senders service3_senders tcp1 sink1 tcp2 sink2 tcp3 sink3

	#Get the current time
	set now [$ns now]

	#Initialize the output string
	set str $now
	append str ", "

	set bw1 0
	for {set i 0} {$i < $service1_senders} {incr i} {
		set bytes [$sink1($i) set bytes_]
		set bw1 [expr $bw1 + $bytes]
		$sink1($i) set bytes_ 0
	}
	append str " "
	append str [expr int($bw1 / $throughputSamplingInterval * 8 / 1000000)];	#throughput in Mbps
	append str ", "

	set bw2 0
	for {set i 0} {$i < $service2_senders} {incr i} {
		set bytes [$sink2($i) set bytes_]
		set bw2 [expr $bw2 + $bytes]
		$sink2($i) set bytes_ 0
	}
	append str " "
	append str [expr int($bw2 / $throughputSamplingInterval * 8 / 1000000)];	#throughput in Mbps
	append str ", "

	set bw3 0
	for {set i 0} {$i < $service3_senders} {incr i} {
		set bytes [$sink3($i) set bytes_]
		set bw3 [expr $bw3 + $bytes]
		$sink3($i) set bytes_ 0
	}
	append str " "
	append str [expr int($bw3 / $throughputSamplingInterval * 8 / 1000000)];	#throughput in Mbps

	puts $throughputfile $str

	#Set next callback time
	$ns at [expr $now + $throughputSamplingInterval] "record"

}

$ns at 0.0 "record"
$ns at [expr $simulationTime] "finish"
$ns run
