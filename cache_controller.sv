module cache_controller #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter LINE_SIZE = 64,
    parameter NUM_SETS = 64,
    parameter OFFSET_WIDTH = $clog2(LINE_SIZE),
    parameter TAG_WIDTH = ADDR_WIDTH - $clog2(NUM_SETS) - $clog2(LINE_SIZE),
    parameter SETS_WIDTH = 6,
    parameter CACHE_SIZE = NUM_SETS * LINE_SIZE
)(
    // Clock and reset
    input  logic clk,
    input  logic rst_n,
    
    // CPU interface
    input  logic [ADDR_WIDTH-1:0] cpu_addr,
    input  logic [DATA_WIDTH-1:0] cpu_write_data,
    output logic [DATA_WIDTH-1:0] cpu_read_data,
    input  logic cpu_read_en,
    input  logic cpu_write_en,
    output logic cpu_ready,
    
    // Memory interface
    output logic [ADDR_WIDTH-1:0] mem_addr,
    output logic [LINE_SIZE*8-1:0] mem_write_data,
    input  logic [LINE_SIZE*8-1:0] mem_read_data,
    output logic mem_read_en,
    output logic mem_write_en,
    input  logic mem_ready
);

typedef enum reg [2:0] {IDLE,CACHE_WRITE,MEM_UPDATE,FETCH,CACHE_READ} STATE;
STATE state,nxt_state;

logic [TAG_WIDTH-1:0] tag;
logic [$clog2(NUM_SETS)-1:0] index;
logic [$clog2(LINE_SIZE)-1:0] offset;

// Tag array signals



// Data cache signals
logic data_read_en, data_write_en,line_write_en,line_read_en,data_hit,data_dirty_bit;
logic [DATA_WIDTH-1:0] data_read_data;
logic [DATA_WIDTH-1:0] data_write_data;
logic [$clog2(NUM_SETS)-1:0] data_index;

logic [OFFSET_WIDTH-1:0] data_offset;
logic [LINE_SIZE*8-1:0] line_write_data, line_read_data;
logic [TAG_WIDTH-1:0]data_tag_in;

data_array  data_cache_inst (
    .clk(clk),
    .rst_n(rst_n),
    .read_en(data_read_en),
    .write_en(data_write_en),
    .index(data_index),
    .offset(data_offset),
    .write_data(data_write_data),
    .line_write_data(line_write_data),
    .read_data(data_read_data),
    .line_read_data(line_read_data),
    .line_write_en(line_write_en),
    .line_read_en(line_read_en),
    .dirty_bit(data_dirty_bit),
    .hit(data_hit),
    .tag_in(data_tag_in)
);




assign {tag,index,offset} = (cpu_write_en || cpu_read_en) ? cpu_addr : {tag,index,offset};

logic op_type_write,data_hit_d;


always_ff @(posedge clk) begin 
    if(!rst_n)begin
        state <= IDLE;
        data_hit_d <= 1'b0;
    end else begin
        state <= nxt_state;
        data_hit_d <= data_hit;
    end
end

always_comb begin 
    // Default values
    nxt_state = state;
    cpu_ready = 1'b0;
    
    
    data_tag_in = tag;
    
    // Data cache controls
    data_read_en = 1'b0;
    data_write_en = 1'b0;
    data_index = index;

    data_offset = offset;
    data_write_data = cpu_write_data;
    line_write_data = mem_read_data;
    line_read_en = 1'b0;
    line_write_en = 1'b0;
    cpu_read_data = data_read_data;
    // Memory interface
    mem_addr = {tag, index, {OFFSET_WIDTH{1'b0}}};  // Aligned to cache line
    mem_write_data = line_read_data;
    mem_read_en = 1'b0;
    mem_write_en = 1'b0;

    
    case (state)
        IDLE: begin
            cpu_ready = 1'b1;
            //op_type_write = 1'b0;

            if(cpu_write_en) begin
                nxt_state = MEM_UPDATE;
                op_type_write = 1'b1;
                data_write_en = 1'b1;
            end else if(cpu_read_en) begin
                nxt_state = MEM_UPDATE;
                op_type_write = 1'b0;
                data_read_en = 1'b1;
            end
            else begin
                nxt_state = IDLE;
            end
        end
        MEM_UPDATE: begin
            if(!op_type_write) begin
                // Read hit
                if(data_hit_d == 1'b1) begin
                    nxt_state = IDLE;
                end else begin
                    nxt_state = FETCH;
                end
            end else begin
                // Write hit
                if(data_hit_d == 1'b1) begin
                    nxt_state = IDLE;
                    mem_write_en = 1'b1;
                    line_read_en = 1'b1;
                end else begin
                    nxt_state = FETCH;
                end
            end
        end
        FETCH : begin
            mem_read_en = 1'b1;
            if(mem_ready) begin
                line_write_en = 'b1;
                if(op_type_write) begin
                    nxt_state = CACHE_WRITE;  
                end else begin
                    nxt_state = CACHE_READ;
                end
            end
        end
        CACHE_WRITE : begin
            data_write_en = 1'b1;
            nxt_state = MEM_UPDATE;
        end
        CACHE_READ : begin
            data_read_en = 1'b1;
            nxt_state = IDLE;
        end
        default: begin
            nxt_state = IDLE;
        end
    endcase
end



endmodule