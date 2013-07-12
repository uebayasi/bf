#define IP_VERSION_INDEX_32 0
#define IP_VERSION_SWAP_32 _BfSwapBe4
#define IP_VERSION_MASK_32 UINT32_C(0xf0000000)
#define IP_VERSION_SHIFT_32 28
#define IP_VERSION_ENUM_32_V4 UINT32_C(0x40000000)
#define IP_VERSION_ENUM_32_V6 UINT32_C(0x60000000)

#define IP_IHL_INDEX_32 0
#define IP_IHL_SWAP_32 _BfSwapBe4
#define IP_IHL_MASK_32 UINT32_C(0x0f000000)
#define IP_IHL_SHIFT_32 24

#define IP_TYPE_INDEX_32 0
#define IP_TYPE_SWAP_32 _BfSwapBe4
#define IP_TYPE_MASK_32 UINT32_C(0x00ff0000)
#define IP_TYPE_SHIFT_32 16

#define IP_LEN_INDEX_32 0
#define IP_LEN_SWAP_32 _BfSwapBe4
#define IP_LEN_MASK_32 UINT32_C(0x0000ffff)
#define IP_LEN_SHIFT_32 0

#define IP_ID_INDEX_32 1
#define IP_ID_SWAP_32 _BfSwapBe4
#define IP_ID_MASK_32 UINT32_C(0xffff0000)
#define IP_ID_SHIFT_32 16

#define IP_FLAGS_DF_INDEX_32 1
#define IP_FLAGS_DF_SWAP_32 _BfSwapBe4
#define IP_FLAGS_DF_MASK_32 UINT32_C(0x00004000)
#define IP_FLAGS_DF_SHIFT_32 14

#define IP_FLAGS_MF_INDEX_32 1
#define IP_FLAGS_MF_SWAP_32 _BfSwapBe4
#define IP_FLAGS_MF_MASK_32 UINT32_C(0x00002000)
#define IP_FLAGS_MF_SHIFT_32 13

#define IP_FRAGOFF_INDEX_32 1
#define IP_FRAGOFF_SWAP_32 _BfSwapBe4
#define IP_FRAGOFF_MASK_32 UINT32_C(0x00001fff)
#define IP_FRAGOFF_SHIFT_32 0

#define IP_TTL_INDEX_32 2
#define IP_TTL_SWAP_32 _BfSwapBe4
#define IP_TTL_MASK_32 UINT32_C(0xff000000)
#define IP_TTL_SHIFT_32 24

#define IP_PROTO_INDEX_32 2
#define IP_PROTO_SWAP_32 _BfSwapBe4
#define IP_PROTO_MASK_32 UINT32_C(0x00ff0000)
#define IP_PROTO_SHIFT_32 16

#define IP_CKSUM_INDEX_32 2
#define IP_CKSUM_SWAP_32 _BfSwapBe4
#define IP_CKSUM_MASK_32 UINT32_C(0x0000ffff)
#define IP_CKSUM_SHIFT_32 0

#define IP_SRC_INDEX_32 3
#define IP_SRC_SWAP_32 _BfSwapBe4

#define IP_DST_INDEX_32 4
#define IP_DST_SWAP_32 _BfSwapBe4
