# RFC 791 - INTERNET PROTOCOL
# 3.1.  Internet Header Format
prefix	IP
endian	big
size	160
4	VERSION 4 V4 6 V6
4	IHL
6	DSCP
2	ECN
16	LEN
16	ID
1
1	FLAGS_DF
1	FLAGS_MF
13	FRAGOFF
8	TTL
8	PROTO
16	CKSUM
32	SRC
32	DST
