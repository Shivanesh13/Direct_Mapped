module data_array #(
    parameter LINE_SIZE = 64,  // In bytes
    parameter NUM_SETS = 64,
    parameter DATA_WIDTH = 32,  // CPU data width
    parameter ADDR_WIDTH = 32,
    parameter TAG_WIDTH = ADDR_WIDTH - $clog2(NUM_SETS) - $clog2(LINE_SIZE)
)(
    input  logic clk,
    input  logic rst_n,
    
    // Control signals
    input  logic read_en,
    input  logic write_en,
    input  logic [$clog2(NUM_SETS)-1:0] index,
    input  logic [TAG_WIDTH-1:0] tag_in,// added 
    //input  logic [$clog2(ASSOCIATIVITY)-1:0] way,
    input  logic [$clog2(LINE_SIZE)-1:0] offset,
    output logic hit, // added 
    
    // Data signals
    input  logic [DATA_WIDTH-1:0] write_data,
    input  logic [LINE_SIZE*8-1:0] line_write_data,  // For line fills
    input  logic line_write_en,  // Control for full line writes
    
    // Output signals
    output logic [DATA_WIDTH-1:0] read_data,
    output logic [LINE_SIZE*8-1:0] line_read_data,  // For writebacks
    output logic dirty_bit, //added
    input  logic line_read_en
);


typedef enum reg [1:0] {IDLE,WORD_READ,LINE_READ} DATA_STATE;

parameter BYTES_PER_WORD = DATA_WIDTH/8;

typedef enum reg [1:0] {EMPTY,VALID,DIRTY} VAL_STATE; 

typedef struct packed {
    reg [LINE_SIZE-1:0][7:0] line_data;
    VAL_STATE valid_state; // 0 
    reg [TAG_WIDTH-1:0] tag_id;
} LINE_DATA;




logic line_valid;
LINE_DATA arr_data[0:NUM_SETS-1];
DATA_STATE state, nxt_state;
reg [LINE_SIZE-1:0][7:0] line_arr;

always_ff @(posedge clk) begin
    if(!rst_n) begin
        state <= IDLE;
    end
    else begin  
        state <= nxt_state;
    end
end 

always_comb begin 
    case (state)
        IDLE : begin
            hit = 1'b0;
            if(!rst_n) begin
                nxt_state = IDLE;
                for(int i = 0;i < NUM_SETS; i++) begin
                    for(int k = 0; k < LINE_SIZE;k++) begin
                        arr_data[i].line_data[k] = '0;
                        arr_data[i].tag_id = '0;
                        arr_data[i].valid_state = EMPTY;
                        line_arr[k] = '0;
                    end
                end
            end
            else if(read_en) begin
                if(arr_data[index].tag_id == tag_in) begin
                    hit = 1'b1;
                    //dirty_bit = (arr_data[index].valid_state == DIRTY);
                    line_arr = arr_data[index].line_data;
                    nxt_state = WORD_READ;
                end
                else begin
                    hit = 1'b0;
                    dirty_bit = (arr_data[index].valid_state == DIRTY);
                    nxt_state = IDLE;
                end
            end else if(write_en) begin
                if(arr_data[index].tag_id == tag_in) begin
                    hit = 1'b1;
                    //dirty_bit = (arr_data[index].valid_state == DIRTY);
                    for(int i = 0;i<BYTES_PER_WORD;i++) begin
                        arr_data[index].line_data[offset + i] = write_data[8*i +: 8];
                    end
                    arr_data[index].tag_id = tag_in;
                    arr_data[index].valid_state = DIRTY;
                end else begin
                    hit = 1'b0;
                    dirty_bit = (arr_data[index].valid_state == DIRTY);
                end
                nxt_state = IDLE;
            end else if(line_write_en) begin
                for(int i=0;i<LINE_SIZE;i++) begin
                    arr_data[index].line_data[i] = line_write_data[8*i +: 8];       
                end
                arr_data[index].tag_id = tag_in;
                arr_data[index].valid_state = VALID;
                nxt_state = IDLE;
            end else if(line_read_en) begin
                    line_arr = arr_data[index];
                    nxt_state = LINE_READ;
            end else begin
                nxt_state = IDLE;
            end
        end 
        WORD_READ : begin
            hit = 1'b0;
            read_data = {line_arr[offset+3],line_arr[offset+2],line_arr[offset+1],line_arr[offset]};
            nxt_state = IDLE;
        end
        LINE_READ : begin
            hit = 1'b0;
            for(int i=0;i<LINE_SIZE;i++) begin
                line_read_data[8*i +: 8] = line_arr[i];       
            end
           nxt_state = IDLE;
        end
    endcase
end

endmodule