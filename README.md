# Direct_Mapped
Implementation of Direct Mapped Design
# Write-Through Cache Implementation

## Overview
This repository contains a SystemVerilog implementation of a direct-mapped cache controller with a write-through policy. In a write-through cache, all write operations update both the cache and the main memory simultaneously, ensuring data consistency across memory hierarchies.

## Architecture

### Key Parameters
- `ADDR_WIDTH`: Width of the address bus (default: 32 bits)
- `DATA_WIDTH`: Width of the data bus (default: 32 bits)
- `LINE_SIZE`: Size of each cache line in bytes (default: 64 bytes)
- `NUM_SETS`: Number of cache sets/lines (default: 64)
- `OFFSET_WIDTH`: Number of bits for the byte offset (calculated)
- `TAG_WIDTH`: Number of bits for the tag field (calculated)
- `CACHE_SIZE`: Total cache size in bytes (NUM_SETS * LINE_SIZE)

### Memory Address Mapping
Each memory address is partitioned into three fields:
```
|-------------------|------------|------------|
|        Tag        |    Index   |   Offset   |
|-------------------|------------|------------|
```
- **Tag**: Identifies which memory block is stored in the cache line
- **Index**: Determines which cache line to access
- **Offset**: Specifies the byte position within the cache line

### Cache Controller States
The cache controller implements a finite state machine with five states:
- `IDLE`: Ready to accept new CPU requests
- `MEM_UPDATE`: Determines if a cache hit or miss occurred
- `FETCH`: Retrieves data from memory on cache miss
- `CACHE_WRITE`: Updates cache with data after a write
- `CACHE_READ`: Reads data from cache after a successful fetch

## Write-Through Implementation Details

The implementation features the following key characteristics:

1. **Direct Write to Memory**: 
   - When a CPU write hits in the cache, the controller updates both the cache and memory
   - The memory is updated by asserting `mem_write_en` and using `line_read_en` to read the line

2. **No Dirty Bit Dependency**:
   - Although the data_array module tracks dirty bits, the write-through policy doesn't rely on them for write operations
   - Every write to the cache is immediately propagated to memory

3. **Write Miss Handling**:
   - On a write miss, the controller fetches the line from memory
   - Updates the cache with the new data
   - Writes the updated data back to memory

4. **Read Operations**:
   - Read operations work similarly to a standard cache
   - On a read hit, data is returned from the cache
   - On a read miss, data is fetched from memory and stored in the cache

## Modules

### cache_controller
The main control module that:
- Interfaces with the CPU and memory
- Manages the state machine
- Controls read and write operations
- Maintains cache coherence through write-through policy

### data_array
Storage module that:
- Stores cache lines and their associated tags
- Provides hit/miss detection
- Supports word-level and line-level operations
- Maintains valid/dirty state for each line

## Interface Signals

### CPU Interface
- `cpu_addr`: Address from the CPU
- `cpu_write_data`: Data to be written
- `cpu_read_data`: Data read from cache or memory
- `cpu_read_en`/`cpu_write_en`: Read/write operation signals
- `cpu_ready`: Signals completion of the operation to the CPU

### Memory Interface
- `mem_addr`: Address for memory access
- `mem_write_data`: Data to be written to memory (full line)
- `mem_read_data`: Data read from memory (full line)
- `mem_read_en`/`mem_write_en`: Memory read/write control signals
- `mem_ready`: Signal from memory indicating operation completion

## Operation Flow

### Write Operation Flow
1. CPU initiates a write with address and data
2. Cache controller checks for hit/miss:
   - On hit: Updates the cache and immediately writes to memory
   - On miss: Fetches the corresponding line from memory, updates the cache, and writes back
3. CPU_ready is asserted when operation completes

### Read Operation Flow
1. CPU initiates a read with address
2. Cache controller checks for hit/miss:
   - On hit: Returns the data from cache
   - On miss: Fetches the line from memory, updates the cache, and returns the data
3. CPU_ready is asserted when operation completes

## Advantages of Write-Through Cache
- **Data Consistency**: Main memory always has the most recent data
- **Simpler Design**: No need for complex writeback mechanisms
- **Reduced Risk**: Minimal data loss in case of system failure
- **Cache Coherence**: Easier to implement in multi-processor systems

## Trade-offs
- **Memory Traffic**: Higher memory bandwidth utilization due to all writes going to memory
- **Performance Impact**: Potential performance bottleneck on write-intensive workloads
- **Power Consumption**: Increased power consumption due to more memory operations

## Usage
To use this cache controller:
1. Instantiate the module in your SystemVerilog design
2. Connect the CPU and memory interfaces
3. Configure the parameters as needed for your specific application

## Verification
To verify the cache controller:
1. Create a testbench with various read and write patterns
2. Ensure that memory is updated immediately on all writes
3. Verify correct operation on cache hits and misses
4. Check that data integrity is maintained across operations

## Future Enhancements
Potential improvements to the design:
- Add write buffer to reduce memory bandwidth requirements
- Implement burst mode for memory operations
- Support for cache flushing and invalidation
- Add performance counters for hit/miss statistics
