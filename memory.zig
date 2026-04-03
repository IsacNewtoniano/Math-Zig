extern "kernel32" fn VirtualAlloc(
	addr: ?*anyopaque,
	size: usize,
	alloc_type: u32,
	protect: u32,
) callconv(.winapi) ?*anyopaque;

extern "kernel32" fn VirtualFree(
	addr: *anyopaque,
	size: usize,
	free_type: u32,
) callconv(.winapi) i32;

const MEM_COMMIT   : u32 = 0x1000;
const MEM_RESERVE  : u32 = 0x2000;
const MEM_RELEASE  : u32 = 0x8000;
const PAGE_READWRITE: u32 = 0x04;

const Allocator_Config = struct {
	max_blocks: u16,
	items_per_block : u16,
	item_size : u32
};

const Minimal_Allocator_Config = struct {
	max_blocks: u8,
	items_per_block : u8,
	item_size : u16
};

fn Allocator(comptime Config: type) type {
	const MetaT = if (Config == Allocator_Config) u32
							else if (Config == Minimal_Allocator_Config) u16
							else @compileError("Config = Allocator_Config OR Config = Minimal_Allocator_Config");

	return struct {
		blocks: [Config.max_blocks][*]?u8,
		FreeList: [Config.max_blocks * Config.items_per_block]MetaT, //stack here
		block_count: usize,
	};
}