/*
 * Defines from https://github.com/perilouswithadollarsign/cstrike15_src/blob/f82112a2388b841d72cb62ca48ab1846dfcc11c8/public/dt_common.h
 */

/*********************************/
#define HIGH_DEFAULT		-121121.121121

// SendProp::m_Flags.
#define SPROP_UNSIGNED			(1<<0)	// Unsigned integer data.

#define SPROP_COORD				(1<<1)	// If this is set, the float/vector is treated like a world coordinate.
                    // Note that the bit count is ignored in this case.

#define SPROP_NOSCALE			(1<<2)	// For floating point, don't scale into range, just take value as is.

#define SPROP_ROUNDDOWN			(1<<3)	// For floating point, limit high value to range minus one bit unit

#define SPROP_ROUNDUP			(1<<4)	// For floating point, limit low value to range minus one bit unit

#define SPROP_NORMAL			(1<<5)	// If this is set, the vector is treated like a normal (only valid for vectors)

#define SPROP_EXCLUDE			(1<<6)	// This is an exclude prop (not excludED, but it points at another prop to be excluded).

#define SPROP_XYZE				(1<<7)	// Use XYZ/Exponent encoding for vectors.

#define SPROP_INSIDEARRAY		(1<<8)	// This tells us that the property is inside an array, so it shouldn't be put into the
                    // flattened property list. Its array will point at it when it needs to.

#define SPROP_PROXY_ALWAYS_YES	(1<<9)	// Set for datatable props using one of the default datatable proxies like
                    // SendProxy_DataTableToDataTable that always send the data to all clients.

#define SPROP_IS_A_VECTOR_ELEM	(1<<10)	// Set automatically if SPROP_VECTORELEM is used.

#define SPROP_COLLAPSIBLE		(1<<11)	// Set automatically if it's a datatable with an offset of 0 that doesn't change the pointer
                    // (ie: for all automatically-chained base classes).
                    // In this case, it can get rid of this SendPropDataTable altogether and spare the
                    // trouble of walking the hierarchy more than necessary.

#define SPROP_COORD_MP					(1<<12) // Like SPROP_COORD, but special handling for multiplayer games
#define SPROP_COORD_MP_LOWPRECISION 	(1<<13) // Like SPROP_COORD, but special handling for multiplayer games where the fractional component only gets a 3 bits instead of 5
#define SPROP_COORD_MP_INTEGRAL			(1<<14) // SPROP_COORD_MP, but coordinates are rounded to integral boundaries
#define SPROP_CELL_COORD				(1<<15) // Like SPROP_COORD, but special encoding for cell coordinates that can't be negative, bit count indicate maximum value
#define SPROP_CELL_COORD_LOWPRECISION 	(1<<16) // Like SPROP_CELL_COORD, but special handling where the fractional component only gets a 3 bits instead of 5
#define SPROP_CELL_COORD_INTEGRAL		(1<<17) // SPROP_CELL_COORD, but coordinates are rounded to integral boundaries

#define SPROP_CHANGES_OFTEN				(1<<18)	// this is an often changed field, moved to head of sendtable so it gets a small index

#define SPROP_VARINT					(1<<19)	// use var int encoded (google protobuf style), note you want to include SPROP_UNSIGNED if needed, its more efficient

#define SPROP_NUMFLAGBITS_NETWORKED		20

/*********************************/

public Plugin myinfo =
{
	name = "SendTable Modifier",
	author = "Poggu#5993",
	description = "Testing weird shit with sendtables",
	version = "0.0.1"
}

public void OnPluginStart()
{
  // Enable sv_sendtables to allow players to join the server when server's SendTable is modified
  SetConVarInt(FindConVar("sv_sendtables"), 1);
  PrintToServer("Started");

  GameData hConfig = LoadGameConfigFile("SendTable-Modifier");
  Address g_SendTableCRC = hConfig.GetAddress("g_SendTableCRC");
  Address g_playerFlagBits = hConfig.GetAddress("PlayerFlagBits");
  Address g_cropFlagsToPlayerFlagBitsLength = hConfig.GetAddress("CropFlagsToPlayerFlagBitsLength");
  Address g_vecBaseVelMin = hConfig.GetAddress("vecBaseVelMin");
  Address g_vecBaseVelMax = hConfig.GetAddress("vecBaseVelMax");
  Address g_vecBaseVelBits = hConfig.GetAddress("vecBaseVelBits");
  Address g_vecBaseVelFlags = hConfig.GetAddress("vecBaseVelFlags");

  // Get addresses from MOV instructions
  Address p_playerFlagBits = LoadFromAddress(g_playerFlagBits, NumberType_Int32);
  Address p_vecBaseVelMin = LoadFromAddress(g_vecBaseVelMin, NumberType_Int32);
  Address p_vecBaseVelMax = LoadFromAddress(g_vecBaseVelMax, NumberType_Int32);
  Address p_vecBaseBits = LoadFromAddress(g_vecBaseVelBits, NumberType_Int32);
  Address p_vecBaseFlags = LoadFromAddress(g_vecBaseVelFlags, NumberType_Int32);

  // Invalidate CRC checksum, yoinked from hud limit unlocker
  StoreToAddress(g_SendTableCRC, 1337, NumberType_Int32);

  /* Move player flag bits */

  // Moves Player Flag Bits from 11 to 32 to include basevelocity
  // https://github.com/perilouswithadollarsign/cstrike15_src/blob/f82112a2388b841d72cb62ca48ab1846dfcc11c8/game/server/player.cpp#L8320
  // Param 2
  StoreToAddress(p_playerFlagBits, 0x20, NumberType_Int32)

  // Precalculated mask to match the new 32 player flag bits
  // (1<<32) - 1
  // https://github.com/perilouswithadollarsign/cstrike15_src/blob/f82112a2388b841d72cb62ca48ab1846dfcc11c8/game/server/player.cpp#L8208
  StoreToAddress(g_cropFlagsToPlayerFlagBitsLength, 0xFFFFFFFF, NumberType_Int32);

  /******************************************************************/


  /* Remove m_vecBaseVelocity limits */

  // Change bits to 32 (default value when param is empty)
  // https://github.com/perilouswithadollarsign/cstrike15_src/blob/f82112a2388b841d72cb62ca48ab1846dfcc11c8/game/server/player.cpp#L8279
  // Param 2
  StoreToAddress(p_vecBaseBits, 32, NumberType_Int32)

  // Set flags to SPROP_NOSCALE (default value when param is empty)
  // https://github.com/perilouswithadollarsign/cstrike15_src/blob/f82112a2388b841d72cb62ca48ab1846dfcc11c8/game/server/player.cpp#L8279
  // Param 3
  StoreToAddress(p_vecBaseFlags, SPROP_NOSCALE, NumberType_Int32)

  // New min value for vecBaseVel
  // Camera acting all weird when this isn't 0. I'm quite unsure why :(
  // https://github.com/perilouswithadollarsign/cstrike15_src/blob/f82112a2388b841d72cb62ca48ab1846dfcc11c8/game/server/player.cpp#L8279
  StoreToAddress(p_vecBaseVelMin, 0.0, NumberType_Int32);

  // New max value for vecBaseVel
  // https://github.com/perilouswithadollarsign/cstrike15_src/blob/f82112a2388b841d72cb62ca48ab1846dfcc11c8/game/server/player.cpp#L8279
  StoreToAddress(p_vecBaseVelMax, 10000.0, NumberType_Int32);

  /******************************************************************/
}