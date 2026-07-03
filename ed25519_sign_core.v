module sign_core (
    input wire clk,
    input wire rst,

    /* Control signals */
    input wire core_ena,
    output reg core_ready,
    output reg core_comp_done,

    /* Secret key */
    input wire [255:0] core_sk,
    /* Public key */
    input wire [255:0] core_pk,
    /* Message, 256 bits only. */
    input wire [255:0] core_M,

    /* A signature is a pair (R,S) */
    output reg [255:0] core_S,
    output reg [255:0] core_R
    );


/*----------------------------------FUNCTIONS---------------------------------*/

function [255:0] changeEndian_256;
    input [255:0] value;
    changeEndian_256 = {value[7:0], value[15:8], value[23:16], value[31:24],
        value[39:32], value[47:40], value[55:48], value[63:56], value[71:64],
        value[79:72], value[87:80], value[95:88], value[103:96], value[111:104],
        value[119:112], value[127:120], value[135:128], value[143:136],
        value[151:144], value[159:152], value[167:160], value[175:168],
        value[183:176], value[191:184], value[199:192], value[207:200],
        value[215:208], value[223:216], value[231:224], value[239:232],
        value[247:240], value[255:248]};
endfunction

function [511:0] changeEndian_512;
    input [511:0] value;
    changeEndian_512 = {value[7:0], value[15:8], value[23:16], value[31:24],
        value[39:32], value[47:40], value[55:48], value[63:56], value[71:64],
        value[79:72], value[87:80], value[95:88], value[103:96], value[111:104],
        value[119:112], value[127:120], value[135:128], value[143:136],
        value[151:144], value[159:152], value[167:160], value[175:168],
        value[183:176], value[191:184], value[199:192], value[207:200],
        value[215:208], value[223:216], value[231:224], value[239:232],
        value[247:240], value[255:248], value[263:256], value[271:264],
        value[279:272], value[287:280], value[295:288], value[303:296],
        value[311:304], value[319:312], value[327:320], value[335:328],
        value[343:336], value[351:344], value[359:352], value[367:360],
        value[375:368], value[383:376], value[391:384], value[399:392],
        value[407:400], value[415:408], value[423:416], value[431:424],
        value[439:432], value[447:440], value[455:448], value[463:456],
        value[471:464], value[479:472], value[487:480], value[495:488],
        value[503:496], value[511:504]};
endfunction

/*---------------------------INTERNAL CONSTANTS-------------------------------*/

localparam [3:0] STATE_IDLE             = 4'd0;
localparam [3:0] STATE_HASH_KEY         = 4'd1;
localparam [3:0] STATE_HASH_SM          = 4'd2;
localparam [3:0] STATE_REDUCE_R         = 4'd3;
localparam [3:0] STATE_SCALAR_MULT      = 4'd4;
localparam [3:0] STATE_INVERT           = 4'd5;
localparam [3:0] STATE_HASH_RAM         = 4'd6;
localparam [3:0] STATE_REDUCE_HRAM      = 4'd7;
localparam [3:0] STATE_MULT_HRAM_A      = 4'd8;
localparam [3:0] STATE_REDUCE_HRAM_A    = 4'd9;
localparam [3:0] STATE_ADD_R_HRAMA      = 4'd10;
localparam [3:0] STATE_REDUCE_FINAL     = 4'd11;
localparam [3:0] STATE_OUTPUT           = 4'd12;

localparam [2:0] ADDR_SCALAR_MULTS      = 3'd0;

localparam [2:0] ADDR_INVERSES          = 3'd1;
localparam [2:0] ADDR_RED_FINAL         = 3'd1;

localparam [2:0] ADDR_RED_R             = 3'd2;
localparam [2:0] ADDR_RED_HRAM_A        = 3'd2;
localparam [2:0] ADDR_HASH_HM           = 3'd2;

localparam [2:0] ADDR_HASH_KEY          = 3'd3;
localparam [2:0] ADDR_RED_HRAM          = 3'd3;
localparam [2:0] ADDR_ADD_R_HRAMA       = 3'd3;

localparam [2:0] ADDR_HASH_RAM          = 3'd4;

localparam [2:0] ADDR_HRAM_A            = 3'd5;

/*-----------------------------------WIRES------------------------------------*/

/* Raw results */
wire [511 : 0] mult_1_out_512;
/* Results modulo 2^255 - 19 */
wire [254 : 0] mult_1_out;

wire hw_ena;
wire hw_ready;
wire [511:0] hw_digest;
wire hw_digest_valid;

wire red_ena;
wire red_ready;
wire [252:0] red_out;
wire red_comp_done;
wire [255:0] red_mult_in_0;
wire [255:0] red_mult_in_1;

wire sm_ena;
wire sm_ready;
wire [254:0] sm_x_out;
wire [254:0] sm_y_out;
wire [254:0] sm_z_out;
wire sm_comp_done;
wire [255:0] sm_mult_in_0;
wire [255:0] sm_mult_in_1;

wire inv_ena;
wire inv_ready;
wire [254:0] inv_x_out;
wire [254:0] inv_y_out;
wire inv_comp_done;
wire [255:0] inv_mult_in_0;
wire [255:0] inv_mult_in_1;

wire bram_1_we;
wire bram_2_we;
wire bram_3_we;

wire [511:0] bram_1_data_out;
wire [255:0] bram_2_data_out;
wire [255:0] bram_3_data_out;

/*------------------------------------REGS------------------------------------*/

reg [3:0] core_state_reg;
reg [3:0] core_state_new;

reg [255 : 0] mult_1_in_0;
reg [255 : 0] mult_1_in_1;

reg [1:0] hw_mode;
reg [255:0] hw_sk;
reg [255:0] hw_h;
reg [255:0] hw_A;
reg [255:0] hw_R;
reg [255:0] hw_M;

reg [511:0] red_in;

reg [511:0] red_mult_out_512;

reg [255:0] sm_scalar;
reg [254:0] sm_mult_out;

reg [254:0] inv_x;
reg [254:0] inv_y;
reg [254:0] inv_z;
reg [254:0] inv_mult_out;

reg [3:0] mult_counter_reg;
reg [3:0] mult_counter_new;

reg [2:0] bram_addr_reg;
reg [2:0] bram_addr_new;

reg [511:0] bram_1_data_in;
reg [255:0] bram_2_data_in;
reg [255:0] bram_3_data_in;

/*--------------------------------COMPONENTS----------------------------------*/

mult_units_512 mult (
    .clk(clk),
    .rst(rst),
    .mult_1_in_0(mult_1_in_0),
    .mult_1_in_1(mult_1_in_1),
    .mult_1_out_512(mult_1_out_512),
    .mult_1_out(mult_1_out)
    );

sha512_wrap hw (
    .clk(clk),
    .rst(rst),
    .hw_ena(hw_ena),
    .hw_ready(hw_ready),
    .hw_error(hw_error),
    .hw_digest_valid(hw_digest_valid),
    .hw_digest(hw_digest),
    .hw_mode(hw_mode),
    .hw_sk(hw_sk),
    .hw_h(hw_h),
    .hw_R(hw_R),
    .hw_A(hw_A),
    .hw_M(hw_M)
    );

barrett_reduce red (
    .clk(clk),
    .rst(rst),
    .red_in(red_in),
    .red_ena(red_ena),
    .red_ready(red_ready),
    .red_comp_done(red_comp_done),
    .red_mult_out_512(red_mult_out_512),
    .red_mult_in_0(red_mult_in_0),
    .red_mult_in_1(red_mult_in_1),
    .red_out(red_out)
    );

scalar_mult sm (
    .clk(clk),
    .rst(rst),
    .sm_ena(sm_ena),
    .scalar(sm_scalar),
    .sm_ready(sm_ready),
    .sm_error(sm_error),
    .sm_comp_done(sm_comp_done),
    .sm_mult_out(sm_mult_out),
    .sm_mult_in_0(sm_mult_in_0),
    .sm_mult_in_1(sm_mult_in_1),
    .sm_x_out(sm_x_out),
    .sm_y_out(sm_y_out),
    .sm_z_out(sm_z_out)
    );

invert inv (
    .clk(clk),
    .rst(rst),
    .inv_x(inv_x),
    .inv_y(inv_y),
    .inv_z(inv_z),
    .inv_ena(inv_ena),
    .inv_ready(inv_ready),
    .inv_comp_done(inv_comp_done),
    .inv_mult_out(inv_mult_out),
    .inv_mult_in_0(inv_mult_in_0),
    .inv_mult_in_1(inv_mult_in_1),
    .inv_x_out(inv_x_out),
    .inv_y_out(inv_y_out)
    );

bram_512 bram_1 (
    .clk(clk),
    .we(bram_1_we),
    .addr(bram_addr_new),
    .data_in(bram_1_data_in),
    .data_out(bram_1_data_out)
    );

bram_256 bram_2 (
    .clk(clk),
    .we(bram_2_we),
    .addr(bram_addr_new),
    .data_in(bram_2_data_in),
    .data_out(bram_2_data_out)
    );

bram_256 bram_3 (
    .clk(clk),
    .we(bram_3_we),
    .addr(bram_addr_new),
    .data_in(bram_3_data_in),
    .data_out(bram_3_data_out)
    );

/*---------------------------------CONNECTIVITY-------------------------------*/

/* Multipliers */
always @* begin
    mult_1_in_0 = 256'bx;
    mult_1_in_1 = 256'bx;

    red_mult_out_512 = 511'bx;

    sm_mult_out = 255'bx;

    inv_mult_out = 255'bx;

    /* Connect the reduction unit */
    if (core_state_reg == STATE_REDUCE_R
        | core_state_reg == STATE_REDUCE_FINAL
        | core_state_reg == STATE_REDUCE_HRAM
        | core_state_reg == STATE_REDUCE_HRAM_A) begin
            mult_1_in_0 = red_mult_in_0;
            mult_1_in_1 = red_mult_in_1;

            red_mult_out_512 = mult_1_out_512;
    end
    if (core_state_reg == STATE_SCALAR_MULT) begin
            mult_1_in_0 = sm_mult_in_0;
            mult_1_in_1 = sm_mult_in_1;

            sm_mult_out = mult_1_out;
    end
    if (core_state_reg == STATE_INVERT) begin
            mult_1_in_0 = inv_mult_in_0;
            mult_1_in_1 = inv_mult_in_1;

            inv_mult_out = mult_1_out;
    end
    if (core_state_reg == STATE_MULT_HRAM_A) begin
            mult_1_in_0 = bram_2_data_out;
            mult_1_in_1 = changeEndian_256({bram_1_data_out[511:507], 3'b0, bram_1_data_out[503:264],
                2'b01, bram_1_data_out[261:256]});
    end

end

/*-----------------------------------INPUT------------------------------------*/

always @* begin
    hw_mode = 2'bx;
    hw_sk = 0;
    hw_h = 0;
    hw_A = 0;
    hw_R = 0;
    hw_M = 0;
    red_in = 512'b0;
    sm_scalar = 256'b0;
    inv_x = 255'b0;
    inv_y = 255'b0;
    inv_z = 255'b0;
    if (core_state_reg == STATE_HASH_KEY) begin
        hw_sk = core_sk;
        hw_mode = 2'b0;
    end
    if (core_state_reg == STATE_HASH_SM) begin
        hw_h = bram_1_data_out[255:0];
        hw_M = core_M;
        hw_mode = 2'b1;
    end
    if (core_state_reg == STATE_REDUCE_R) begin
        red_in = bram_1_data_out;
    end
    if (core_state_reg == STATE_SCALAR_MULT) begin
        sm_scalar = bram_2_data_out;
    end
    if (core_state_reg == STATE_INVERT) begin
        inv_x = bram_1_data_out;
        inv_y = bram_2_data_out;
        inv_z = bram_3_data_out;
    end
    if (core_state_reg == STATE_HASH_RAM) begin
        hw_R = changeEndian_256({bram_1_data_out[0], bram_2_data_out[254:0]});
        hw_A = core_pk;
        hw_M = core_M;
        hw_mode = 2'b10;
    end
    if (core_state_reg == STATE_REDUCE_HRAM) begin
        red_in = (bram_1_data_out);
    end
    if (core_state_reg == STATE_REDUCE_HRAM_A) begin
        red_in = bram_1_data_out;
    end
    if (core_state_reg == STATE_REDUCE_FINAL) begin
        red_in = bram_3_data_out;
    end
end

/*------------------------------------RAM-------------------------------------*/

assign bram_1_we = hw_digest_valid | sm_comp_done | inv_comp_done
                                   | (mult_counter_reg == 4'h0);

assign bram_2_we = (red_comp_done &&
                   (core_state_reg == STATE_REDUCE_R ||
                    core_state_reg == STATE_REDUCE_HRAM))
                 | sm_comp_done | inv_comp_done;
assign bram_3_we = (red_comp_done &&
                   (core_state_reg == STATE_REDUCE_FINAL ||
                    core_state_reg == STATE_REDUCE_HRAM_A))
                 | (core_state_reg == STATE_ADD_R_HRAMA)
                 | sm_comp_done | inv_comp_done;

always @(posedge clk) begin
    if (rst) begin
        bram_addr_reg <= 3'b0;
    end
    else begin
        bram_addr_reg <= bram_addr_new;
    end
end

// Manage the addresses.
always @* begin
    /* Default is no change */
    bram_addr_new = bram_addr_reg;
    if (core_state_reg == STATE_HASH_KEY && hw_digest_valid)
        bram_addr_new = ADDR_HASH_KEY;
    else if (core_state_reg == STATE_HASH_SM && hw_digest_valid)
        bram_addr_new = ADDR_HASH_HM;
    else if (core_state_reg == STATE_REDUCE_R && red_comp_done)
        bram_addr_new = ADDR_RED_R;
    else if (core_state_reg == STATE_SCALAR_MULT && sm_comp_done)
        bram_addr_new = ADDR_SCALAR_MULTS;
    else if (core_state_reg == STATE_INVERT && inv_comp_done)
        bram_addr_new = ADDR_INVERSES;
    else if (core_state_reg == STATE_HASH_RAM && hw_digest_valid)
        bram_addr_new = ADDR_HASH_RAM;
    else if (core_state_reg == STATE_REDUCE_HRAM && red_comp_done)
        bram_addr_new = ADDR_RED_HRAM;
    else if (core_state_reg == STATE_MULT_HRAM_A && mult_counter_reg == 4'b0)
        bram_addr_new = ADDR_HRAM_A;
    else if (core_state_reg == STATE_REDUCE_HRAM_A && red_comp_done)
        bram_addr_new = ADDR_RED_HRAM_A;
    else if (core_state_reg == STATE_ADD_R_HRAMA)
        bram_addr_new = ADDR_ADD_R_HRAMA;
    else if (core_state_reg == STATE_REDUCE_FINAL && red_comp_done)
        bram_addr_new = ADDR_RED_FINAL;
end

// Write to BRAM_1
always @* begin
    bram_1_data_in = 512'bx;
    if (core_state_reg == STATE_HASH_KEY) begin
        bram_1_data_in = hw_digest;
    end
    else if (core_state_reg == STATE_HASH_SM) begin
        bram_1_data_in = changeEndian_512(hw_digest);
    end
    else if (core_state_reg == STATE_HASH_RAM) begin
        bram_1_data_in = changeEndian_512(hw_digest);
    end
    else if (core_state_reg == STATE_MULT_HRAM_A) begin
        bram_1_data_in = mult_1_out_512;
    end
    else if (core_state_reg == STATE_SCALAR_MULT) begin
        bram_1_data_in = sm_x_out;
    end
    else if (core_state_reg == STATE_INVERT) begin
        bram_1_data_in = inv_x_out;
    end
end

// Write to BRAM_2
always @* begin
    bram_2_data_in = 256'bx;
    if (core_state_reg == STATE_REDUCE_R) begin
        bram_2_data_in = red_out;
    end
    else if (core_state_reg == STATE_REDUCE_HRAM) begin
        bram_2_data_in = red_out;
    end
    else if (core_state_reg == STATE_SCALAR_MULT) begin
        bram_2_data_in = sm_y_out;
    end
    else if (core_state_reg == STATE_INVERT) begin
        bram_2_data_in = inv_y_out;
    end
end

// Write to BRAM_3
always @* begin
    bram_3_data_in = 256'bx;
    if (core_state_reg == STATE_REDUCE_FINAL) begin
        bram_3_data_in = red_out;
    end
    else if (core_state_reg == STATE_REDUCE_HRAM_A) begin
        bram_3_data_in = red_out;
    end
    else if (core_state_reg == STATE_SCALAR_MULT) begin
        bram_3_data_in = sm_z_out;
    end
    else if (core_state_reg == STATE_ADD_R_HRAMA) begin
        bram_3_data_in = bram_2_data_out + bram_3_data_out;
    end
end

/* Enable hash unit */
assign hw_ena = (core_state_reg == STATE_HASH_KEY & hw_ready)
              | (core_state_reg == STATE_HASH_SM & hw_ready)
              | (core_state_reg == STATE_HASH_RAM & hw_ready)
              | (core_state_reg == STATE_HASH_RAM & hw_ready);
/* Enable reduction unit */
assign red_ena = (core_state_reg == STATE_REDUCE_R && red_ready)
               | (core_state_reg == STATE_REDUCE_HRAM && red_ready)
               | (core_state_reg == STATE_REDUCE_HRAM_A && red_ready)
               | (core_state_reg == STATE_REDUCE_FINAL && red_ready);
/* Enable scalar multiplication unit */
assign sm_ena = (core_state_reg == STATE_SCALAR_MULT && sm_ready);
/* Enable inversion unit */
assign inv_ena = (core_state_reg == STATE_INVERT && inv_ready);

/*-------------------------------------FSM------------------------------------*/

always @(posedge clk) begin
    if (rst) begin
        core_state_reg   <= STATE_IDLE;
        mult_counter_reg <= 4'hf;
    end
    else begin
        core_state_reg   <= core_state_new;
        mult_counter_reg <= mult_counter_new;
    end
end

always @* begin
    core_state_new   = core_state_reg;
    mult_counter_new = mult_counter_reg;
    core_ready       = 1'b0;

    case (core_state_reg)
        STATE_IDLE:
            begin
                core_ready = 1'b1;
                if (core_ena) begin
                    core_state_new = STATE_HASH_KEY;
                end
            end
        STATE_HASH_KEY:
            begin
                if (hw_digest_valid) begin
                    core_state_new = STATE_HASH_SM;
                end
            end
        STATE_HASH_SM:
            begin
                if (hw_digest_valid) begin
                    core_state_new = STATE_REDUCE_R;
                end
            end
        STATE_REDUCE_R:
            begin
                if (red_comp_done) begin
                    core_state_new = STATE_SCALAR_MULT;
                end
            end
        STATE_SCALAR_MULT:
            begin
                if (sm_comp_done) begin
                    core_state_new = STATE_INVERT;
                end
            end
        STATE_INVERT:
            begin
                if (inv_comp_done) begin
                    core_state_new = STATE_HASH_RAM;
                end
            end
        STATE_HASH_RAM:
            begin
                if (hw_digest_valid) begin
                    core_state_new = STATE_REDUCE_HRAM;
                end
            end
        STATE_REDUCE_HRAM:
            begin
                if (red_comp_done) begin
                    core_state_new = STATE_MULT_HRAM_A;
                    mult_counter_new = 4'd10;
                end
            end
        STATE_MULT_HRAM_A:
            begin
                mult_counter_new = mult_counter_reg - 1'b1;
                if (mult_counter_reg == 4'b0) begin
                    core_state_new = STATE_REDUCE_HRAM_A;
                end
            end
        STATE_REDUCE_HRAM_A:
            begin
                if (red_comp_done) begin
                    core_state_new = STATE_ADD_R_HRAMA;
                end
            end
        STATE_ADD_R_HRAMA:
            begin
                core_state_new = STATE_REDUCE_FINAL;
            end
        STATE_REDUCE_FINAL:
            begin
                if (red_comp_done) begin
                    core_state_new = STATE_OUTPUT;
                end
            end
        STATE_OUTPUT:
            begin
                core_state_new = STATE_IDLE;
            end
        default:
            core_state_new = STATE_IDLE;
    endcase
end

/*-----------------------------------OUTPUT-----------------------------------*/

always @* begin
    core_comp_done = 1'b0;
    core_S = 256'bx;
    core_R = 256'bx;
    if (core_state_reg == STATE_OUTPUT) begin
        core_comp_done = 1'b1;
        core_S = changeEndian_256({3'b0, bram_3_data_out[252:0]});
        core_R = changeEndian_256({bram_1_data_out[0], bram_2_data_out[254:0]});
    end
end

endmodule


/* This module computes H(k), H(hM) or H(R,A,M), only 256 bit M are supported */

module sha512_wrap (
    input wire clk,
    input wire rst,

    input wire hw_ena,

    output wire hw_ready,
    output wire hw_error,
    output wire hw_digest_valid,
    output wire [511:0] hw_digest,

    input wire [1:0] hw_mode,
    /* Mode 1, H(sk); hash the secret key */
    input wire [255:0] hw_sk,
    /* Mode 2, H(h_b,...,h_{2b-1},M); hash the randomizer and the message. */
    input wire [255:0] hw_h,
    /* Mode 3, H(R,A,M); Bind R, the compressed point. A, the public key. And M,
    * the message. */
    input wire [255:0] hw_R,
    input wire [255:0] hw_A,
    /* The message for mode 2 & 3; 256 bits. */
    input wire [255:0] hw_M
    );


/*---------------------------INTERNAL CONSTANTS-------------------------------*/

/*  The hash always fits in one block. */
localparam STATE_IDLE = 0;
localparam STATE_INIT = 1;
localparam STATE_BUSY = 2;

/*------------------------------------REGS------------------------------------*/
reg [1023:0] sha_block_reg;
reg [1023:0] sha_block_new;

reg ready_flag;
reg error_flag;

reg [1:0] hash_wrap_state_reg;
reg [1:0] hash_wrap_state_new;

reg sha_init;
reg sha_next;

reg hw_comp_done;
/*------------------------------------WIRES-----------------------------------*/

wire [1:0] sha_mode;
wire [1023:0] sha_block;
wire sha_ready;
wire [511:0] sha_digest;
wire sha_digest_valid;

/*--------------------------------COMPONENTS----------------------------------*/

sha512_core sha512 (
    .clk(clk),
    .reset_n(!rst),
    .init(sha_init),
    .next(sha_next),
    .mode(sha_mode),
    /* .work_factor(work_factor), */
    /* .work_factor_num(work_factor_num), */
    .block(sha_block),
    .ready(sha_ready),
    /* .state_wr_data(state_wr_data), */
    .digest(sha_digest),
    .digest_valid(sha_digest_valid)
    );
/*---------------------------------CONNECTIVITY-------------------------------*/

assign hw_ready = ready_flag;
assign hw_error = error_flag;
assign sha_block = sha_block_reg;

assign sha_mode = 3;  // Always SHA-512
assign hw_digest = sha_digest;
assign hw_digest_valid = hw_comp_done;

/*-------------------------------------FSM------------------------------------*/

/* Synchronous state update */
always @(posedge clk) begin
    if (rst) begin
        hash_wrap_state_reg <= STATE_IDLE;
        sha_block_reg <= 1024'b0;
    end
    else begin
        hash_wrap_state_reg <= hash_wrap_state_new;
        sha_block_reg <= sha_block_new;
    end
end

/* Asynchronous next state logic */
always @* begin
    hash_wrap_state_new = STATE_IDLE;

    ready_flag = 0;
    error_flag = 0;

    sha_init = 0;
    sha_next = 0;
    sha_block_new = sha_block_reg;
    hw_comp_done = 1'b0;

    case (hash_wrap_state_reg)
        STATE_IDLE:
            begin
                ready_flag = 1;

                if (hw_ena & sha_ready) begin
                    hash_wrap_state_new = STATE_INIT;
                end
                else if (hw_ena) begin
                    error_flag = 1;
                end
            end
        STATE_INIT:
            begin
                hash_wrap_state_new = STATE_BUSY;
                sha_init = 1;
            end
        STATE_BUSY:
            begin
                hash_wrap_state_new = STATE_BUSY;
                if (sha_digest_valid) begin
                    hw_comp_done = 1'b1;
                    hash_wrap_state_new = STATE_IDLE;
                end
            end
    endcase

    /* A hash will be one block, either 256, 384 or 768 bits.
    * This also preforms the required input padding. */
    case (hw_mode)
        // H(k)
        0 : sha_block_new = {hw_sk, 1'b1, 639'b0, 128'd256};
        // H(hM)
        1 : sha_block_new = {hw_h, hw_M, 1'b1, 383'b0, 128'd512};
        // H(R,A,M)
        2 : sha_block_new = {hw_R, hw_A, hw_M, 1'b1, 127'b0, 128'd768};
        3 :
            begin
                error_flag = 1;
                hash_wrap_state_new = STATE_IDLE;
            end
    endcase
end

endmodule


//======================================================================
//
// sha512_core.v
// -------------
// Verilog 2001 implementation of the SHA-512 hash function.
// This is the internal core with wide interfaces.
//
//
// Author: Joachim Strombergson
// Copyright (c) 2014, NORDUnet A/S
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
// - Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//
// - Redistributions in binary form must reproduce the above copyright
//   notice, this list of conditions and the following disclaimer in the
//   documentation and/or other materials provided with the distribution.
//
// - Neither the name of the NORDUnet nor the names of its contributors may
//   be used to endorse or promote products derived from this software
//   without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
// IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
// TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module sha512_core(
                   input wire            clk,
                   input wire            reset_n,

                   input wire            init,
                   input wire            next,
                   input wire [1 : 0]    mode,

                   input wire            work_factor,
                   input wire [31 : 0]   work_factor_num,

                   input wire [1023 : 0] block,

                   output wire           ready,

                   input wire [31 : 0]   state_wr_data,
                   input wire            state00_we,
                   input wire            state01_we,
                   input wire            state02_we,
                   input wire            state03_we,
                   input wire            state04_we,
                   input wire            state05_we,
                   input wire            state06_we,
                   input wire            state07_we,
                   input wire            state08_we,
                   input wire            state09_we,
                   input wire            state10_we,
                   input wire            state11_we,
                   input wire            state12_we,
                   input wire            state13_we,
                   input wire            state14_we,
                   input wire            state15_we,

                   output wire [511 : 0] digest,
                   output wire           digest_valid
                  );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter SHA512_ROUNDS = 79;

  parameter CTRL_IDLE   = 0;
  parameter CTRL_ROUNDS = 1;
  parameter CTRL_DONE   = 2;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [63 : 0] a_reg;
  reg [63 : 0] a_new;
  reg [63 : 0] b_reg;
  reg [63 : 0] b_new;
  reg [63 : 0] c_reg;
  reg [63 : 0] c_new;
  reg [63 : 0] d_reg;
  reg [63 : 0] d_new;
  reg [63 : 0] e_reg;
  reg [63 : 0] e_new;
  reg [63 : 0] f_reg;
  reg [63 : 0] f_new;
  reg [63 : 0] g_reg;
  reg [63 : 0] g_new;
  reg [63 : 0] h_reg;
  reg [63 : 0] h_new;
  reg          a_h_we;

  reg [63 : 0] H0_reg;
  reg [63 : 0] H0_new;
  reg [63 : 0] H1_reg;
  reg [63 : 0] H1_new;
  reg [63 : 0] H2_reg;
  reg [63 : 0] H2_new;
  reg [63 : 0] H3_reg;
  reg [63 : 0] H3_new;
  reg [63 : 0] H4_reg;
  reg [63 : 0] H4_new;
  reg [63 : 0] H5_reg;
  reg [63 : 0] H5_new;
  reg [63 : 0] H6_reg;
  reg [63 : 0] H6_new;
  reg [63 : 0] H7_reg;
  reg [63 : 0] H7_new;
  reg          H_we;

  reg [6 : 0] t_ctr_reg;
  reg [6 : 0] t_ctr_new;
  reg         t_ctr_we;
  reg         t_ctr_inc;
  reg         t_ctr_rst;

  reg [31 : 0] work_factor_ctr_reg;
  reg [31 : 0] work_factor_ctr_new;
  reg          work_factor_ctr_rst;
  reg          work_factor_ctr_inc;
  reg          work_factor_ctr_done;
  reg          work_factor_ctr_we;

  reg digest_valid_reg;
  reg digest_valid_new;
  reg digest_valid_we;

  reg [1 : 0] sha512_ctrl_reg;
  reg [1 : 0] sha512_ctrl_new;
  reg         sha512_ctrl_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg digest_init;
  reg digest_update;

  reg state_init;
  reg state_update;

  reg first_block;

  reg ready_flag;

  reg [63 : 0] t1;
  reg [63 : 0] t2;

  wire [63 : 0] k_data;

  reg           w_init;
  reg           w_next;
  wire [63 : 0] w_data;

  wire [63 : 0] H0_0;
  wire [63 : 0] H0_1;
  wire [63 : 0] H0_2;
  wire [63 : 0] H0_3;
  wire [63 : 0] H0_4;
  wire [63 : 0] H0_5;
  wire [63 : 0] H0_6;
  wire [63 : 0] H0_7;


  //----------------------------------------------------------------
  // Module instantiantions.
  //----------------------------------------------------------------
  sha512_k_constants k_constants_inst(
                                      .addr(t_ctr_reg),
                                      .K(k_data)
                                     );


  sha512_h_constants h_constants_inst(
                                      .mode(mode),

                                      .H0(H0_0),
                                      .H1(H0_1),
                                      .H2(H0_2),
                                      .H3(H0_3),
                                      .H4(H0_4),
                                      .H5(H0_5),
                                      .H6(H0_6),
                                      .H7(H0_7)
                                     );


  sha512_w_mem w_mem_inst(
                          .clk(clk),
                          .reset_n(reset_n),

                          .block(block),

                          .init(w_init),
                          .next(w_next),
                          .w(w_data)
                         );


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign ready = ready_flag;

  assign digest = {H0_reg, H1_reg, H2_reg, H3_reg,
                   H4_reg, H5_reg, H6_reg, H7_reg};

  assign digest_valid = digest_valid_reg;


  //----------------------------------------------------------------
  // reg_update
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @ (posedge clk)
    begin : reg_update
      if (!reset_n)
        begin
          a_reg               <= 64'h0000000000000000;
          b_reg               <= 64'h0000000000000000;
          c_reg               <= 64'h0000000000000000;
          d_reg               <= 64'h0000000000000000;
          e_reg               <= 64'h0000000000000000;
          f_reg               <= 64'h0000000000000000;
          g_reg               <= 64'h0000000000000000;
          h_reg               <= 64'h0000000000000000;
          H0_reg              <= 64'h0000000000000000;
          H1_reg              <= 64'h0000000000000000;
          H2_reg              <= 64'h0000000000000000;
          H3_reg              <= 64'h0000000000000000;
          H4_reg              <= 64'h0000000000000000;
          H5_reg              <= 64'h0000000000000000;
          H6_reg              <= 64'h0000000000000000;
          H7_reg              <= 64'h0000000000000000;
          work_factor_ctr_reg <= 32'h00000000;
          digest_valid_reg    <= 0;
          t_ctr_reg           <= 7'h00;
          sha512_ctrl_reg     <= CTRL_IDLE;
        end
      else
        begin

          if (a_h_we)
            begin
              a_reg <= a_new;
              b_reg <= b_new;
              c_reg <= c_new;
              d_reg <= d_new;
              e_reg <= e_new;
              f_reg <= f_new;
              g_reg <= g_new;
              h_reg <= h_new;
            end

          if (H_we)
            begin
              H0_reg <= H0_new;
              H1_reg <= H1_new;
              H2_reg <= H2_new;
              H3_reg <= H3_new;
              H4_reg <= H4_new;
              H5_reg <= H5_new;
              H6_reg <= H6_new;
              H7_reg <= H7_new;
            end

          if (state00_we)
            H0_reg <= {state_wr_data, H0_reg[31 : 0]};

          if (state01_we)
            H0_reg <= {H0_reg[63 : 32], state_wr_data};

          if (state02_we)
            H1_reg <= {state_wr_data, H1_reg[31 : 0]};

          if (state03_we)
            H1_reg <= {H1_reg[63 : 32], state_wr_data};

          if (state04_we)
            H2_reg <= {state_wr_data, H2_reg[31 : 0]};

          if (state05_we)
            H2_reg <= {H2_reg[63 : 32], state_wr_data};

          if (state06_we)
            H3_reg <= {state_wr_data, H3_reg[31 : 0]};

          if (state07_we)
            H3_reg <= {H3_reg[63 : 32], state_wr_data};

          if (state08_we)
            H4_reg <= {state_wr_data, H4_reg[31 : 0]};

          if (state09_we)
            H4_reg <= {H4_reg[63 : 32], state_wr_data};

          if (state10_we)
            H5_reg <= {state_wr_data, H5_reg[31 : 0]};

          if (state11_we)
            H5_reg <= {H5_reg[63 : 32], state_wr_data};

          if (state12_we)
            H6_reg <= {state_wr_data, H6_reg[31 : 0]};

          if (state13_we)
            H6_reg <= {H6_reg[63 : 32], state_wr_data};

          if (state14_we)
            H7_reg <= {state_wr_data, H7_reg[31 : 0]};

          if (state15_we)
            H7_reg <= {H7_reg[63 : 32], state_wr_data};

          if (t_ctr_we)
            begin
              t_ctr_reg <= t_ctr_new;
            end

          if (work_factor_ctr_we)
            begin
              work_factor_ctr_reg <= work_factor_ctr_new;
            end

          if (digest_valid_we)
            begin
              digest_valid_reg <= digest_valid_new;
            end

          if (sha512_ctrl_we)
            begin
              sha512_ctrl_reg <= sha512_ctrl_new;
            end
        end
    end // reg_update


  //----------------------------------------------------------------
  // digest_logic
  //
  // The logic needed to init as well as update the digest.
  //----------------------------------------------------------------
  always @*
    begin : digest_logic
      H0_new = 64'h00000000;
      H1_new = 64'h00000000;
      H2_new = 64'h00000000;
      H3_new = 64'h00000000;
      H4_new = 64'h00000000;
      H5_new = 64'h00000000;
      H6_new = 64'h00000000;
      H7_new = 64'h00000000;
      H_we = 0;

      if (digest_init)
        begin
          H0_new = H0_0;
          H1_new = H0_1;
          H2_new = H0_2;
          H3_new = H0_3;
          H4_new = H0_4;
          H5_new = H0_5;
          H6_new = H0_6;
          H7_new = H0_7;
          H_we = 1;
        end

      if (digest_update)
        begin
          H0_new = H0_reg + a_reg;
          H1_new = H1_reg + b_reg;
          H2_new = H2_reg + c_reg;
          H3_new = H3_reg + d_reg;
          H4_new = H4_reg + e_reg;
          H5_new = H5_reg + f_reg;
          H6_new = H6_reg + g_reg;
          H7_new = H7_reg + h_reg;
          H_we = 1;
        end
    end // digest_logic


  //----------------------------------------------------------------
  // t1_logic
  //
  // The logic for the T1 function.
  //----------------------------------------------------------------
  always @*
    begin : t1_logic
      reg [63 : 0] sum1;
      reg [63 : 0] ch;

      sum1 = {e_reg[13 : 0], e_reg[63 : 14]} ^
             {e_reg[17 : 0], e_reg[63 : 18]} ^
             {e_reg[40 : 0], e_reg[63 : 41]};

      ch = (e_reg & f_reg) ^ ((~e_reg) & g_reg);

      t1 = h_reg + sum1 + ch + k_data + w_data;
    end // t1_logic


  //----------------------------------------------------------------
  // t2_logic
  //
  // The logic for the T2 function
  //----------------------------------------------------------------
  always @*
    begin : t2_logic
      reg [63 : 0] sum0;
      reg [63 : 0] maj;

      sum0 = {a_reg[27 : 0], a_reg[63 : 28]} ^
             {a_reg[33 : 0], a_reg[63 : 34]} ^
             {a_reg[38 : 0], a_reg[63 : 39]};

      maj = (a_reg & b_reg) ^ (a_reg & c_reg) ^ (b_reg & c_reg);

      t2 = sum0 + maj;
    end // t2_logic


  //----------------------------------------------------------------
  // state_logic
  //
  // The logic needed to init as well as update the state during
  // round processing.
  //----------------------------------------------------------------
  always @*
    begin : state_logic
      a_new  = 64'h00000000;
      b_new  = 64'h00000000;
      c_new  = 64'h00000000;
      d_new  = 64'h00000000;
      e_new  = 64'h00000000;
      f_new  = 64'h00000000;
      g_new  = 64'h00000000;
      h_new  = 64'h00000000;
      a_h_we = 0;

      if (state_init)
        begin
          if (first_block)
            begin
              a_new  = H0_0;
              b_new  = H0_1;
              c_new  = H0_2;
              d_new  = H0_3;
              e_new  = H0_4;
              f_new  = H0_5;
              g_new  = H0_6;
              h_new  = H0_7;
              a_h_we = 1;
            end
          else
            begin
              a_new  = H0_reg;
              b_new  = H1_reg;
              c_new  = H2_reg;
              d_new  = H3_reg;
              e_new  = H4_reg;
              f_new  = H5_reg;
              g_new  = H6_reg;
              h_new  = H7_reg;
              a_h_we = 1;
            end
        end

      if (state_update)
        begin
          a_new  = t1 + t2;
          b_new  = a_reg;
          c_new  = b_reg;
          d_new  = c_reg;
          e_new  = d_reg + t1;
          f_new  = e_reg;
          g_new  = f_reg;
          h_new  = g_reg;
          a_h_we = 1;
        end
    end // state_logic


  //----------------------------------------------------------------
  // t_ctr
  //
  // Update logic for the round counter, a monotonically
  // increasing counter with reset.
  //----------------------------------------------------------------
  always @*
    begin : t_ctr
      t_ctr_new = 7'h00;
      t_ctr_we  = 0;

      if (t_ctr_rst)
        begin
          t_ctr_new = 7'h00;
          t_ctr_we  = 1;
        end

      if (t_ctr_inc)
        begin
          t_ctr_new = t_ctr_reg + 1'b1;
          t_ctr_we  = 1;
        end
    end // t_ctr


  //----------------------------------------------------------------
  // work_factor_ctr
  //
  // Work factor counter logic.
  //----------------------------------------------------------------
  always @*
    begin : work_factor_ctr
      work_factor_ctr_new  = 32'h00000000;
      work_factor_ctr_we   = 0;
      work_factor_ctr_done = 0;

      if (work_factor_ctr_reg == work_factor_num)
        begin
          work_factor_ctr_done = 1;
        end

      if (work_factor_ctr_rst)
        begin
          work_factor_ctr_new  = 32'h00000000;
          work_factor_ctr_we   = 1;
        end

      if (work_factor_ctr_inc)
        begin
          work_factor_ctr_new  = work_factor_ctr_reg + 1'b1;
          work_factor_ctr_we   = 1;
        end
    end // work_factor_ctr


  //----------------------------------------------------------------
  // sha512_ctrl_fsm
  //
  // Logic for the state machine controlling the core behaviour.
  //----------------------------------------------------------------
  always @*
    begin : sha512_ctrl_fsm
      digest_init         = 0;
      digest_update       = 0;

      state_init          = 0;
      state_update        = 0;

      first_block         = 0;
      ready_flag          = 0;

      w_init              = 0;
      w_next              = 0;

      t_ctr_inc           = 0;
      t_ctr_rst           = 0;

      digest_valid_new    = 0;
      digest_valid_we     = 0;

      work_factor_ctr_rst = 0;
      work_factor_ctr_inc = 0;

      sha512_ctrl_new     = CTRL_IDLE;
      sha512_ctrl_we      = 0;


      case (sha512_ctrl_reg)
        CTRL_IDLE:
          begin
            ready_flag = 1;

            if (init)
              begin
                work_factor_ctr_rst = 1;
                digest_init         = 1;
                w_init              = 1;
                state_init          = 1;
                first_block         = 1;
                t_ctr_rst           = 1;
                digest_valid_new    = 0;
                digest_valid_we     = 1;
                sha512_ctrl_new     = CTRL_ROUNDS;
                sha512_ctrl_we      = 1;
              end

            if (next)
              begin
                work_factor_ctr_rst = 1;
                w_init              = 1;
                state_init          = 1;
                t_ctr_rst           = 1;
                digest_valid_new    = 0;
                digest_valid_we     = 1;
                sha512_ctrl_new     = CTRL_ROUNDS;
                sha512_ctrl_we      = 1;
              end
          end


        CTRL_ROUNDS:
          begin
            w_next       = 1;
            state_update = 1;
            t_ctr_inc    = 1;

            if (t_ctr_reg == SHA512_ROUNDS)
              begin
                work_factor_ctr_inc = 1;
                sha512_ctrl_new     = CTRL_DONE;
                sha512_ctrl_we      = 1;
              end
          end


        CTRL_DONE:
          begin
            if (work_factor)
              begin
                if (!work_factor_ctr_done)
                  begin
                    w_init              = 1;
                    state_init          = 1;
                    t_ctr_rst           = 1;
                    sha512_ctrl_new     = CTRL_ROUNDS;
                    sha512_ctrl_we      = 1;
                  end
                else
                  begin
                    digest_update    = 1;
                    digest_valid_new = 1;
                    digest_valid_we  = 1;
                    sha512_ctrl_new  = CTRL_IDLE;
                    sha512_ctrl_we   = 1;
                  end
              end
            else
              begin
                digest_update    = 1;
                digest_valid_new = 1;
                digest_valid_we  = 1;
                sha512_ctrl_new  = CTRL_IDLE;
                sha512_ctrl_we   = 1;
              end
          end
      endcase // case (sha512_ctrl_reg)
    end // sha512_ctrl_fsm

endmodule // sha512_core

//======================================================================
// EOF sha512_core.v
//======================================================================


//======================================================================
//
// sha512_h_constants.v
// ---------------------
// The H initial constants for the different modes in SHA-512.
//
//
// Author: Joachim Strombergson
// Copyright (c) 2014, NORDUnet A/S
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
// - Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//
// - Redistributions in binary form must reproduce the above copyright
//   notice, this list of conditions and the following disclaimer in the
//   documentation and/or other materials provided with the distribution.
//
// - Neither the name of the NORDUnet nor the names of its contributors may
//   be used to endorse or promote products derived from this software
//   without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
// IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
// TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module sha512_h_constants(
                          input wire  [1 : 0]  mode,

                          output wire [63 : 0] H0,
                          output wire [63 : 0] H1,
                          output wire [63 : 0] H2,
                          output wire [63 : 0] H3,
                          output wire [63 : 0] H4,
                          output wire [63 : 0] H5,
                          output wire [63 : 0] H6,
                          output wire [63 : 0] H7
                         );

  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [63 : 0] tmp_H0;
  reg [63 : 0] tmp_H1;
  reg [63 : 0] tmp_H2;
  reg [63 : 0] tmp_H3;
  reg [63 : 0] tmp_H4;
  reg [63 : 0] tmp_H5;
  reg [63 : 0] tmp_H6;
  reg [63 : 0] tmp_H7;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign H0 = tmp_H0;
  assign H1 = tmp_H1;
  assign H2 = tmp_H2;
  assign H3 = tmp_H3;
  assign H4 = tmp_H4;
  assign H5 = tmp_H5;
  assign H6 = tmp_H6;
  assign H7 = tmp_H7;

  
  //----------------------------------------------------------------
  // mode_mux
  //
  // Based on the given mode, the correct H constants are selected.
  //----------------------------------------------------------------
  always @*
    begin : mode_mux
      case(mode)
        0:
          begin
            // SHA-512/224
            tmp_H0 = 64'h8c3d37c819544da2;
            tmp_H1 = 64'h73e1996689dcd4d6;
            tmp_H2 = 64'h1dfab7ae32ff9c82;
            tmp_H3 = 64'h679dd514582f9fcf;
            tmp_H4 = 64'h0f6d2b697bd44da8;
            tmp_H5 = 64'h77e36f7304c48942;
            tmp_H6 = 64'h3f9d85a86a1d36c8;
            tmp_H7 = 64'h1112e6ad91d692a1;
          end

        1:
          begin
            // SHA-512/256
            tmp_H0 = 64'h22312194fc2bf72c; 
            tmp_H1 = 64'h9f555fa3c84c64c2; 
            tmp_H2 = 64'h2393b86b6f53b151; 
            tmp_H3 = 64'h963877195940eabd; 
            tmp_H4 = 64'h96283ee2a88effe3; 
            tmp_H5 = 64'hbe5e1e2553863992; 
            tmp_H6 = 64'h2b0199fc2c85b8aa; 
            tmp_H7 = 64'h0eb72ddc81c52ca2;
          end
        
        2:
          begin
            // SHA-384
            tmp_H0 = 64'hcbbb9d5dc1059ed8;
            tmp_H1 = 64'h629a292a367cd507;
            tmp_H2 = 64'h9159015a3070dd17; 
            tmp_H3 = 64'h152fecd8f70e5939; 
            tmp_H4 = 64'h67332667ffc00b31; 
            tmp_H5 = 64'h8eb44a8768581511; 
            tmp_H6 = 64'hdb0c2e0d64f98fa7; 
            tmp_H7 = 64'h47b5481dbefa4fa4;
          end
        
        3:
          begin
            // SHA-512
            tmp_H0 = 64'h6a09e667f3bcc908;
            tmp_H1 = 64'hbb67ae8584caa73b;
            tmp_H2 = 64'h3c6ef372fe94f82b; 
            tmp_H3 = 64'ha54ff53a5f1d36f1; 
            tmp_H4 = 64'h510e527fade682d1; 
            tmp_H5 = 64'h9b05688c2b3e6c1f; 
            tmp_H6 = 64'h1f83d9abfb41bd6b; 
            tmp_H7 = 64'h5be0cd19137e2179;  
          end
      endcase // case (addr)
    end // block: mode_mux
endmodule // sha512_h_constants

//======================================================================
// sha512_h_constants.v
//======================================================================


//======================================================================
//
// sha512_k_constants.v
// --------------------
// The table K with constants in the SHA-512 hash function.
//
//
// Author: Joachim Strombergson
// Copyright (c) 2014, NORDUnet A/S
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
// - Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//
// - Redistributions in binary form must reproduce the above copyright
//   notice, this list of conditions and the following disclaimer in the
//   documentation and/or other materials provided with the distribution.
//
// - Neither the name of the NORDUnet nor the names of its contributors may
//   be used to endorse or promote products derived from this software
//   without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
// IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
// TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module sha512_k_constants(
                          input wire  [6 : 0]  addr,
                          output wire [63 : 0] K
                         );

  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [63 : 0] tmp_K;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign K = tmp_K;
  
  
  //----------------------------------------------------------------
  // addr_mux
  //----------------------------------------------------------------
  always @*
    begin : addr_mux
      case(addr)
        0:
          begin
            tmp_K = 64'h428a2f98d728ae22;
          end
        
        1:
          begin
            tmp_K = 64'h7137449123ef65cd;
          end

        2:
          begin
            tmp_K = 64'hb5c0fbcfec4d3b2f;
          end

        3:
          begin
            tmp_K = 64'he9b5dba58189dbbc;
          end

        4:
          begin
            tmp_K = 64'h3956c25bf348b538;
          end

        5:
          begin
            tmp_K = 64'h59f111f1b605d019;
          end

        6:
          begin
            tmp_K = 64'h923f82a4af194f9b;
          end

        7:
          begin
            tmp_K = 64'hab1c5ed5da6d8118;
          end

        8:
          begin
            tmp_K = 64'hd807aa98a3030242;
          end

        9:
          begin
            tmp_K = 64'h12835b0145706fbe;
          end

        10:
          begin
            tmp_K = 64'h243185be4ee4b28c;
          end

        11:
          begin
            tmp_K = 64'h550c7dc3d5ffb4e2;
          end

        12:
          begin
            tmp_K = 64'h72be5d74f27b896f;
          end

        13:
          begin
            tmp_K = 64'h80deb1fe3b1696b1;
          end

        14:
          begin
            tmp_K = 64'h9bdc06a725c71235;
          end
        
        15:
          begin
            tmp_K = 64'hc19bf174cf692694;
          end
        
        16:
          begin
            tmp_K = 64'he49b69c19ef14ad2;
          end

        17:
          begin
            tmp_K = 64'hefbe4786384f25e3;
          end

        18:
          begin
            tmp_K = 64'h0fc19dc68b8cd5b5;
          end
        
        19:
          begin
            tmp_K = 64'h240ca1cc77ac9c65;
          end
        
        20:
          begin
            tmp_K = 64'h2de92c6f592b0275;
          end

        21:
          begin
            tmp_K = 64'h4a7484aa6ea6e483;
          end

        22:
          begin
            tmp_K = 64'h5cb0a9dcbd41fbd4;
          end

        23:
          begin
            tmp_K = 64'h76f988da831153b5;
          end

        24:
          begin
            tmp_K = 64'h983e5152ee66dfab;
          end
        
        25:
          begin
            tmp_K = 64'ha831c66d2db43210;
          end

        26:
          begin
            tmp_K = 64'hb00327c898fb213f;
          end
        
        27:
          begin
            tmp_K = 64'hbf597fc7beef0ee4;
          end

        28:
          begin
            tmp_K = 64'hc6e00bf33da88fc2;
          end

        29:
          begin
            tmp_K = 64'hd5a79147930aa725;
          end

        30:
          begin
            tmp_K = 64'h06ca6351e003826f;
          end

        31:
          begin
            tmp_K = 64'h142929670a0e6e70;
          end

        32:
          begin
            tmp_K = 64'h27b70a8546d22ffc;
          end

        33:
          begin
            tmp_K = 64'h2e1b21385c26c926;
          end

        34:
          begin
            tmp_K = 64'h4d2c6dfc5ac42aed;
          end

        35:
          begin
            tmp_K = 64'h53380d139d95b3df;
          end

        36:
          begin
            tmp_K = 64'h650a73548baf63de;
          end

        37:
          begin
            tmp_K = 64'h766a0abb3c77b2a8;
          end

        38:
          begin
            tmp_K = 64'h81c2c92e47edaee6;
          end

        39:
          begin
            tmp_K = 64'h92722c851482353b;
          end

        40:
          begin
            tmp_K = 64'ha2bfe8a14cf10364;
          end

        41:
          begin
            tmp_K = 64'ha81a664bbc423001;
          end

        42:
          begin
            tmp_K = 64'hc24b8b70d0f89791;
          end
        
        43:
          begin
            tmp_K = 64'hc76c51a30654be30;
          end
        
        44:
          begin
            tmp_K = 64'hd192e819d6ef5218;
          end

        45:
          begin
            tmp_K = 64'hd69906245565a910;
          end
        
        46:
          begin
            tmp_K = 64'hf40e35855771202a;
          end
        
        47:
          begin
            tmp_K = 64'h106aa07032bbd1b8;
          end
        
        48:
          begin
            tmp_K = 64'h19a4c116b8d2d0c8;
          end
        
        49:
          begin
            tmp_K = 64'h1e376c085141ab53;
          end

        50:
          begin
            tmp_K = 64'h2748774cdf8eeb99;
          end

        51:
          begin
            tmp_K = 64'h34b0bcb5e19b48a8;
          end

        52:
          begin
            tmp_K = 64'h391c0cb3c5c95a63;
          end

        53:
          begin
            tmp_K = 64'h4ed8aa4ae3418acb;
          end

        54:
          begin
            tmp_K = 64'h5b9cca4f7763e373;
          end

        55:
          begin
            tmp_K = 64'h682e6ff3d6b2b8a3;
          end

        56:
          begin
            tmp_K = 64'h748f82ee5defb2fc;
          end
        
        57:
          begin
            tmp_K = 64'h78a5636f43172f60;
          end
        
        58:
          begin
            tmp_K = 64'h84c87814a1f0ab72;
          end
        
        59:
          begin
            tmp_K = 64'h8cc702081a6439ec;
          end

        60:
          begin
            tmp_K = 64'h90befffa23631e28;
          end

        61:
          begin
            tmp_K = 64'ha4506cebde82bde9;
          end

        62:
          begin
            tmp_K = 64'hbef9a3f7b2c67915;
          end

        63:
          begin
            tmp_K = 64'hc67178f2e372532b;
          end

        64:
          begin
            tmp_K = 64'hca273eceea26619c;
          end

        65:
          begin
            tmp_K = 64'hd186b8c721c0c207;
          end

        66:
          begin
            tmp_K = 64'heada7dd6cde0eb1e;
          end

        67:
          begin
            tmp_K = 64'hf57d4f7fee6ed178;
          end

        68:
          begin
            tmp_K = 64'h06f067aa72176fba;
          end

        69:
          begin
            tmp_K = 64'h0a637dc5a2c898a6;
          end

        70:
          begin
            tmp_K = 64'h113f9804bef90dae;
          end

        71:
          begin
            tmp_K = 64'h1b710b35131c471b;
          end

        72:
          begin
            tmp_K = 64'h28db77f523047d84;
          end

        73:
          begin
            tmp_K = 64'h32caab7b40c72493;
          end

        74:
          begin
            tmp_K = 64'h3c9ebe0a15c9bebc;
          end

        75:
          begin
            tmp_K = 64'h431d67c49c100d4c;
          end
        
        76:
          begin
            tmp_K = 64'h4cc5d4becb3e42b6;
          end

        77:
          begin
            tmp_K = 64'h597f299cfc657e2a;
          end

        78:
          begin
            tmp_K = 64'h5fcb6fab3ad6faec;
          end
        
        79:
          begin
            tmp_K = 64'h6c44198c4a475817;
          end

        default:
          begin
            tmp_K = 64'h0000000000000000;
          end
      endcase // case (addr)
    end // block: addr_mux
endmodule // sha512_k_constants

//======================================================================
// sha512_k_constants.v
//======================================================================


//======================================================================
//
// sha512_w_mem_regs.v
// -------------------
// The W memory for the SHA-512 core. This version uses 16
// 32-bit registers as a sliding window to generate the 64 words.
//
//
// Author: Joachim Strombergson
// Copyright (c) 2014 NORDUnet A/S
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
// - Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//
// - Redistributions in binary form must reproduce the above copyright
//   notice, this list of conditions and the following disclaimer in the
//   documentation and/or other materials provided with the distribution.
//
// - Neither the name of the NORDUnet nor the names of its contributors may
//   be used to endorse or promote products derived from this software
//   without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
// IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
// TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module sha512_w_mem(
                    input wire            clk,
                    input wire            reset_n,

                    input wire [1023 : 0] block,

                    input wire            init,
                    input wire            next,
                    output wire [63 : 0]  w
                   );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter CTRL_IDLE   = 1'b0;
  parameter CTRL_UPDATE = 1'b1;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [63 : 0] w_mem [0 : 15];
  reg [63 : 0] w_mem00_new;
  reg [63 : 0] w_mem01_new;
  reg [63 : 0] w_mem02_new;
  reg [63 : 0] w_mem03_new;
  reg [63 : 0] w_mem04_new;
  reg [63 : 0] w_mem05_new;
  reg [63 : 0] w_mem06_new;
  reg [63 : 0] w_mem07_new;
  reg [63 : 0] w_mem08_new;
  reg [63 : 0] w_mem09_new;
  reg [63 : 0] w_mem10_new;
  reg [63 : 0] w_mem11_new;
  reg [63 : 0] w_mem12_new;
  reg [63 : 0] w_mem13_new;
  reg [63 : 0] w_mem14_new;
  reg [63 : 0] w_mem15_new;
  reg          w_mem_we;

  reg [6 : 0] w_ctr_reg;
  reg [6 : 0] w_ctr_new;
  reg         w_ctr_we;
  reg         w_ctr_inc;
  reg         w_ctr_rst;

  reg         sha512_w_mem_ctrl_reg;
  reg         sha512_w_mem_ctrl_new;
  reg         sha512_w_mem_ctrl_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [63 : 0] w_tmp;
  reg [63 : 0] w_new;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign w = w_tmp;


  //----------------------------------------------------------------
  // reg_update
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @ (posedge clk)
    begin : reg_update
      if (!reset_n)
        begin
          w_mem[00]             <= 64'h0000000000000000;
          w_mem[01]             <= 64'h0000000000000000;
          w_mem[02]             <= 64'h0000000000000000;
          w_mem[03]             <= 64'h0000000000000000;
          w_mem[04]             <= 64'h0000000000000000;
          w_mem[05]             <= 64'h0000000000000000;
          w_mem[06]             <= 64'h0000000000000000;
          w_mem[07]             <= 64'h0000000000000000;
          w_mem[08]             <= 64'h0000000000000000;
          w_mem[09]             <= 64'h0000000000000000;
          w_mem[10]             <= 64'h0000000000000000;
          w_mem[11]             <= 64'h0000000000000000;
          w_mem[12]             <= 64'h0000000000000000;
          w_mem[13]             <= 64'h0000000000000000;
          w_mem[14]             <= 64'h0000000000000000;
          w_mem[15]             <= 64'h0000000000000000;
          w_ctr_reg             <= 7'h00;
          sha512_w_mem_ctrl_reg <= CTRL_IDLE;
        end
      else
        begin
          if (w_mem_we)
            begin
              w_mem[00] <= w_mem00_new;
              w_mem[01] <= w_mem01_new;
              w_mem[02] <= w_mem02_new;
              w_mem[03] <= w_mem03_new;
              w_mem[04] <= w_mem04_new;
              w_mem[05] <= w_mem05_new;
              w_mem[06] <= w_mem06_new;
              w_mem[07] <= w_mem07_new;
              w_mem[08] <= w_mem08_new;
              w_mem[09] <= w_mem09_new;
              w_mem[10] <= w_mem10_new;
              w_mem[11] <= w_mem11_new;
              w_mem[12] <= w_mem12_new;
              w_mem[13] <= w_mem13_new;
              w_mem[14] <= w_mem14_new;
              w_mem[15] <= w_mem15_new;
            end

          if (w_ctr_we)
            begin
              w_ctr_reg <= w_ctr_new;
            end

          if (sha512_w_mem_ctrl_we)
            begin
              sha512_w_mem_ctrl_reg <= sha512_w_mem_ctrl_new;
            end
        end
    end // reg_update


  //----------------------------------------------------------------
  // select_w
  //
  // Mux for the external read operation. This is where we exract
  // the W variable.
  //----------------------------------------------------------------
  always @*
    begin : select_w
      if (w_ctr_reg < 16)
        begin
          w_tmp = w_mem[w_ctr_reg[3 : 0]];
        end
      else
        begin
          w_tmp = w_new;
        end
    end // select_w


  //----------------------------------------------------------------
  // w_new_logic
  //
  // Logic that calculates the next value to be inserted into
  // the sliding window of the memory.
  //----------------------------------------------------------------
  always @*
    begin : w_mem_update_logic
      reg [63 : 0] w_0;
      reg [63 : 0] w_1;
      reg [63 : 0] w_9;
      reg [63 : 0] w_14;
      reg [63 : 0] d0;
      reg [63 : 0] d1;

      w_mem00_new = 64'h0000000000000000;
      w_mem01_new = 64'h0000000000000000;
      w_mem02_new = 64'h0000000000000000;
      w_mem03_new = 64'h0000000000000000;
      w_mem04_new = 64'h0000000000000000;
      w_mem05_new = 64'h0000000000000000;
      w_mem06_new = 64'h0000000000000000;
      w_mem07_new = 64'h0000000000000000;
      w_mem08_new = 64'h0000000000000000;
      w_mem09_new = 64'h0000000000000000;
      w_mem10_new = 64'h0000000000000000;
      w_mem11_new = 64'h0000000000000000;
      w_mem12_new = 64'h0000000000000000;
      w_mem13_new = 64'h0000000000000000;
      w_mem14_new = 64'h0000000000000000;
      w_mem15_new = 64'h0000000000000000;
      w_mem_we    = 0;

      w_0  = w_mem[0];
      w_1  = w_mem[1];
      w_9  = w_mem[9];
      w_14 = w_mem[14];

      d0 = {w_1[0],     w_1[63 : 1]} ^ // ROTR1
           {w_1[7 : 0], w_1[63 : 8]} ^ // ROTR8
           {7'b0000000, w_1[63 : 7]};  // SHR7

      d1 = {w_14[18 : 0], w_14[63 : 19]} ^ // ROTR19
           {w_14[60 : 0], w_14[63 : 61]} ^ // ROTR61
           {6'b000000,    w_14[63 : 6]};   // SHR6

      w_new = w_0 + d0 + w_9 + d1;

      if (init)
        begin
          w_mem00_new = block[1023 : 960];
          w_mem01_new = block[959  : 896];
          w_mem02_new = block[895  : 832];
          w_mem03_new = block[831  : 768];
          w_mem04_new = block[767  : 704];
          w_mem05_new = block[703  : 640];
          w_mem06_new = block[639  : 576];
          w_mem07_new = block[575  : 512];
          w_mem08_new = block[511  : 448];
          w_mem09_new = block[447  : 384];
          w_mem10_new = block[383  : 320];
          w_mem11_new = block[319  : 256];
          w_mem12_new = block[255  : 192];
          w_mem13_new = block[191  : 128];
          w_mem14_new = block[127  :  64];
          w_mem15_new = block[63   :   0];
          w_mem_we    = 1;
        end
      else if (w_ctr_reg > 15)
        begin
          w_mem00_new = w_mem[01];
          w_mem01_new = w_mem[02];
          w_mem02_new = w_mem[03];
          w_mem03_new = w_mem[04];
          w_mem04_new = w_mem[05];
          w_mem05_new = w_mem[06];
          w_mem06_new = w_mem[07];
          w_mem07_new = w_mem[08];
          w_mem08_new = w_mem[09];
          w_mem09_new = w_mem[10];
          w_mem10_new = w_mem[11];
          w_mem11_new = w_mem[12];
          w_mem12_new = w_mem[13];
          w_mem13_new = w_mem[14];
          w_mem14_new = w_mem[15];
          w_mem15_new = w_new;
          w_mem_we    = 1;
        end
    end // w_mem_update_logic


  //----------------------------------------------------------------
  // w_ctr
  // W schedule adress counter. Counts from 0x10 to 0x3f and
  // is used to expand the block into words.
  //----------------------------------------------------------------
  always @*
    begin : w_ctr
      w_ctr_new = 0;
      w_ctr_we  = 0;

      if (w_ctr_rst)
        begin
          w_ctr_new = 7'h00;
          w_ctr_we  = 1;
        end

      if (w_ctr_inc)
        begin
          w_ctr_new = w_ctr_reg + 7'h01;
          w_ctr_we  = 1;
        end
    end // w_ctr


  //----------------------------------------------------------------
  // sha512_w_mem_fsm
  // Logic for the w shedule FSM.
  //----------------------------------------------------------------
  always @*
    begin : sha512_w_mem_fsm
      w_ctr_rst = 0;
      w_ctr_inc = 0;

      sha512_w_mem_ctrl_new = CTRL_IDLE;
      sha512_w_mem_ctrl_we  = 0;

      case (sha512_w_mem_ctrl_reg)
        CTRL_IDLE:
          begin
            if (init)
              begin
                w_ctr_rst             = 1;
                sha512_w_mem_ctrl_new = CTRL_UPDATE;
                sha512_w_mem_ctrl_we  = 1;
              end
          end

        CTRL_UPDATE:
          begin
            if (next)
              begin
                w_ctr_inc = 1;
              end

            if (w_ctr_reg == 7'h3f)
              begin
                sha512_w_mem_ctrl_new = CTRL_IDLE;
                sha512_w_mem_ctrl_we  = 1;
              end
          end
      endcase // case (sha512_ctrl_reg)
    end // sha512_ctrl_fsm

endmodule // sha512_w_mem

//======================================================================
// sha512_w_mem.v
//======================================================================


/* Multiply a point by a scalar. In practice the scalar is 253 bits but upto 256
* is possible.*/

module scalar_mult (
    input wire clk,
    input wire rst,

    /* To enable this modules computation */
    input wire sm_ena,

    /* Scalar */
    input wire [255 : 0] scalar,

    /* Ready to start */
    output wire sm_ready,
    output wire sm_error,
    output reg sm_comp_done,

    /* Results from the dedicated multipliers */
    input wire [254 : 0] sm_mult_out,

    /* To the multipliers */
    output reg [255 : 0] sm_mult_in_0,
    output reg [255 : 0] sm_mult_in_1,

    /* Output (x, y, z) */
    output reg [254 : 0] sm_x_out,
    output reg [254 : 0] sm_y_out,
    output reg [254 : 0] sm_z_out
    );


/*---------------------------INTERNAL CONSTANTS-------------------------------*/

localparam STATE_IDLE = 0;
localparam STATE_INIT = 1;
localparam STATE_PHA1 = 2;
localparam STATE_PHA2 = 3;
localparam STATE_PHA3 = 4;
localparam STATE_PHA4 = 5;
localparam STATE_NEXT = 6;
localparam STATE_OUTP = 7;

/*------------------------------------REGS------------------------------------*/

reg [254 : 0] x1;
reg [254 : 0] y1;
reg [254 : 0] t1;
reg [254 : 0] z1;
reg [254 : 0] t1_pipeline;
reg [254 : 0] z1_pipeline;

reg [254 : 0] proc_1_sub_in_0;
reg [254 : 0] proc_1_sub_in_1;

reg [254 : 0] proc_2_sub_in_0;
reg [254 : 0] proc_2_sub_in_1;

reg [254 : 0] proc_3_add_in_0;
reg [254 : 0] proc_3_add_in_1;

reg [254 : 0] proc_4_add_in_0;
reg [254 : 0] proc_4_add_in_1;

reg [255 : 0] proc_1_mult_in_0;
reg [255 : 0] proc_1_mult_in_1;
reg [255 : 0] proc_2_mult_in_0;
reg [255 : 0] proc_2_mult_in_1;
reg [255 : 0] proc_3_mult_in_0;
reg [255 : 0] proc_3_mult_in_1;
reg [255 : 0] proc_4_mult_in_0;
reg [255 : 0] proc_4_mult_in_1;

reg [255 : 0] data_in_dram_proc_1;
reg [255 : 0] data_in_dram_proc_2;
reg [255 : 0] data_in_dram_proc_3;
reg [255 : 0] data_in_dram_proc_4;

reg ready_flag;
reg error_flag;

reg [3:0] sm_state_reg;
reg [3:0] sm_state_new;

reg [4:0] sm_round_reg;
reg [4:0] sm_round_new;

reg [4:0] sm_dur_reg;
reg [4:0] sm_dur_new;

reg [7:0] idx_reg;

/*---------------------------------CONNECTIVITY-------------------------------*/

assign sm_ready = ready_flag;
assign sm_error = error_flag;

/*-----------------------------------WIRES------------------------------------*/

wire [255 : 0] proc_1_sub_out;
wire [255 : 0] proc_2_sub_out;
wire [255 : 0] proc_3_add_out;
wire [255 : 0] proc_4_add_out;

wire [12 : 0] addr;

wire [254 : 0] x_data_out;
wire [254 : 0] y_data_out;
wire [254 : 0] t_data_out;

wire en_wr_dram_proc_1;
wire en_wr_dram_proc_2;
wire en_wr_dram_proc_3;
wire en_wr_dram_proc_4;

wire [255 : 0] data_out_dram_proc_1;
wire [255 : 0] data_out_dram_proc_2;
wire [255 : 0] data_out_dram_proc_3;
wire [255 : 0] data_out_dram_proc_4;
/*---------------------------------COMPONENTS---------------------------------*/

reg_256 dram_proc_1 (
    .clk(clk),
    .en_wr(en_wr_dram_proc_1),
    .data_in(data_in_dram_proc_1),
    .data_out(data_out_dram_proc_1)
    );

reg_256 dram_proc_2 (
    .clk(clk),
    .en_wr(en_wr_dram_proc_2),
    .data_in(data_in_dram_proc_2),
    .data_out(data_out_dram_proc_2)
    );

reg_256 dram_proc_3 (
    .clk(clk),
    .en_wr(en_wr_dram_proc_3),
    .data_in(data_in_dram_proc_3),
    .data_out(data_out_dram_proc_3)
    );

reg_256 dram_proc_4 (
    .clk(clk),
    .en_wr(en_wr_dram_proc_4),
    .data_in(data_in_dram_proc_4),
    .data_out(data_out_dram_proc_4)
    );

precomp_rom #("x_precomp.dat") x_mem (
    .clk(clk),
    .addr(addr),
    .data_out(x_data_out)
);

precomp_rom #("y_precomp.dat") y_mem (
    .clk(clk),
    .addr(addr),
    .data_out(y_data_out)
);

precomp_rom #("t_precomp.dat") t_mem (
    .clk(clk),
    .addr(addr),
    .data_out(t_data_out)
);


sub proc_1_sub (
    .clk(clk),
    .rst(rst),
    .sub_in_0(proc_1_sub_in_0),
    .sub_in_1(proc_1_sub_in_1),
    .sub_out(proc_1_sub_out)
);

sub proc_2_sub (
    .clk(clk),
    .rst(rst),
    .sub_in_0(proc_2_sub_in_0),
    .sub_in_1(proc_2_sub_in_1),
    .sub_out(proc_2_sub_out)
);

add proc_3_add (
    .clk(clk),
    .rst(rst),
    .add_in_0(proc_3_add_in_0),
    .add_in_1(proc_3_add_in_1),
    .add_out(proc_3_add_out)
);

add proc_4_add (
    .clk(clk),
    .rst(rst),
    .add_in_0(proc_4_add_in_0),
    .add_in_1(proc_4_add_in_1),
    .add_out(proc_4_add_out)
);

/*------------------------------------MATH------------------------------------*/

/* Processor 1 parallel unified addition. */
always @* begin
    proc_1_sub_in_0 = 255'bx;
    proc_1_sub_in_1 = 255'bx;
    proc_1_mult_in_0 = 256'bx;
    proc_1_mult_in_1 = 256'bx;

    if (sm_state_reg == STATE_PHA1) begin
            /* R_1 = Y_1 - X_1 */
            proc_1_sub_in_0 = y1;
            proc_1_sub_in_1 = x1;
    end
    else if (sm_state_reg == STATE_PHA2) begin
            /* R_5 = R_1 * R_2 */
            proc_1_mult_in_0 = proc_1_sub_out;
            proc_1_mult_in_1 = proc_2_sub_out;
    end
    else if (sm_state_reg == STATE_PHA3) begin
            /* R_1 = R_6 - R_5 */
            proc_1_sub_in_0 = data_out_dram_proc_2;
            proc_1_sub_in_1 = data_out_dram_proc_1;
    end
    else if (sm_state_reg == STATE_PHA4) begin
            /* X_1 = R_1 * R_2 */
            proc_1_mult_in_0 = proc_1_sub_out;
            proc_1_mult_in_1 = proc_2_sub_out;
    end
end

// Processor 2
always @* begin
    proc_2_sub_in_0 = 255'bx;
    proc_2_sub_in_1 = 255'bx;
    proc_2_mult_in_0 = 256'bx;
    proc_2_mult_in_1 = 256'bx;
    if (sm_state_reg == STATE_PHA1) begin
            /* R_2 = Y_2 - X_2 */
            proc_2_sub_in_0 = y_data_out;
            proc_2_sub_in_1 = x_data_out;
    end
    else if (sm_state_reg == STATE_PHA2) begin
            /* R_6 = R_3 * R_4 */
            proc_2_mult_in_0 = data_out_dram_proc_3;
            proc_2_mult_in_1 = data_out_dram_proc_4;
    end
    else if (sm_state_reg == STATE_PHA3) begin
            /* R_2 = R_8 - R_7 */
            proc_2_sub_in_0 = data_out_dram_proc_4;
            proc_2_sub_in_1 = data_out_dram_proc_3;
    end
    else if (sm_state_reg == STATE_PHA4) begin
            /* Y_1 = R_3 * R_4 */
            proc_2_mult_in_0 = data_out_dram_proc_3;
            proc_2_mult_in_1 = data_out_dram_proc_4;
    end
end

// Processor 3
always @* begin
    proc_3_add_in_0 = 255'bx;
    proc_3_add_in_1 = 255'bx;
    proc_3_mult_in_0 = 256'bx;
    proc_3_mult_in_1 = 256'bx;
    if (sm_state_reg == STATE_PHA1) begin
            /* R_3 = Y_1 + X_1 */
            proc_3_add_in_0 = y1;
            proc_3_add_in_1 = x1;
	end
    else if (sm_state_reg == STATE_PHA2) begin
            /* R_7 = T_1 * T_2 */
            proc_3_mult_in_0 = t1_pipeline;
            proc_3_mult_in_1 = t_data_out;
    end
    else if (sm_state_reg == STATE_PHA3) begin
            /* R_3 = R_8 + R_7 */
            proc_3_add_in_0 = data_out_dram_proc_4;
            proc_3_add_in_1 = data_out_dram_proc_3;
    end
    else if (sm_state_reg == STATE_PHA4) begin
            /* T_1 = R_1 * R_4 */
            proc_3_mult_in_0 = data_out_dram_proc_1;
            proc_3_mult_in_1 = data_out_dram_proc_4;
    end
end

// Processor 4
always @* begin
    proc_4_add_in_0 = 255'bx;
    proc_4_add_in_1 = 255'bx;
    proc_4_mult_in_0 = 256'bx;
    proc_4_mult_in_1 = 256'bx;
    if (sm_state_reg == STATE_PHA1) begin
            /* R_4 = Y_2 + X_2 */
            proc_4_add_in_0 = y_data_out;
            proc_4_add_in_1 = x_data_out;
    end
    else if (sm_state_reg == STATE_PHA2) begin
            /* R_8 = Z_1 * Z_2 */
            proc_4_mult_in_0 = z1_pipeline;
            proc_4_mult_in_1 = 256'b10;
    end
    else if (sm_state_reg == STATE_PHA3) begin
            /* R_4 = R_6 + R_5 */
            proc_4_add_in_0 = data_out_dram_proc_2;
            proc_4_add_in_1 = data_out_dram_proc_1;
    end
    else if (sm_state_reg == STATE_PHA4) begin
            proc_4_mult_in_0 = data_out_dram_proc_2;
            proc_4_mult_in_1 = data_out_dram_proc_3;
    end
end

/*----------------------------------PIPELINE----------------------------------*/

/* Assign the right values to x1, y1 and t1 */
always @(posedge clk) begin
    if (rst) begin
        x1 <= 255'b0;
        y1 <= 255'b0;
        t1 <= 255'b0;
    end
    else if (sm_state_reg == STATE_INIT) begin
        x1 <= x_data_out;
        y1 <= y_data_out;
        t1 <= t_data_out;
        z1 <= 255'b1;
        t1_pipeline <= 255'bx;
        z1_pipeline <= 255'bx;
    end
    else if (sm_state_reg == STATE_PHA1) begin
        x1 <= 255'bx;
        y1 <= 255'bx;
        t1 <= 255'bx;
        z1 <= 255'b1;
        t1_pipeline <= t1;
        z1_pipeline <= z1;
    end
    /* Z_1 = R_2*R_3 arrives from the shared multiplier exactly when
     * sm_dur_reg == 0 (same cycle dram_proc_4 is written). Sampling it any
     * later (e.g. in STATE_NEXT) reads the pipeline slot of a don't-care
     * job: behavioral sim masks that via X-optimism, synthesized hardware
     * returns garbage. */
    else if (sm_state_reg == STATE_PHA4 && sm_dur_reg == 5'd0) begin
        z1 <= sm_mult_out;
    end
    else if (sm_state_reg == STATE_NEXT) begin
        x1 <= data_out_dram_proc_1;
        y1 <= data_out_dram_proc_2;
        t1 <= data_out_dram_proc_3;
        t1_pipeline <= 255'bx;
        z1_pipeline <= 255'bx;
    end
end


/*----------------------------------ROUTING-----------------------------------*/

always @* begin
    sm_mult_in_0 = 256'bx;
    sm_mult_in_1 = 256'bx;
    if (sm_dur_reg == 16) begin
        sm_mult_in_0 = proc_1_mult_in_0;
        sm_mult_in_1 = proc_1_mult_in_1;
    end
    if (sm_dur_reg == 15) begin
        sm_mult_in_0 = proc_2_mult_in_0;
        sm_mult_in_1 = proc_2_mult_in_1;
    end
    if (sm_dur_reg == 14) begin
        sm_mult_in_0 = proc_3_mult_in_0;
        sm_mult_in_1 = proc_3_mult_in_1;
    end
    if (sm_dur_reg == 13) begin
        sm_mult_in_0 = proc_4_mult_in_0;
        sm_mult_in_1 = proc_4_mult_in_1;
    end
end

/*------------------------------------RAM-------------------------------------*/

assign addr = {sm_round_reg, idx_reg};

/* This implicitly only happens during phase 2 and 4 */
assign en_wr_dram_proc_1 = (sm_dur_reg == 16 | sm_dur_reg == 3);
assign en_wr_dram_proc_2 = (sm_dur_reg == 16 | sm_dur_reg == 2);
assign en_wr_dram_proc_3 = (sm_dur_reg == 16 | sm_dur_reg == 1);
assign en_wr_dram_proc_4 = (sm_dur_reg == 16 | sm_dur_reg == 0);

always @* begin
    data_in_dram_proc_1 = 256'bx;
    data_in_dram_proc_2 = 256'bx;
    data_in_dram_proc_3 = 256'bx;
    data_in_dram_proc_4 = 256'bx;
    if (sm_dur_reg == 16) begin
        data_in_dram_proc_1 = proc_1_sub_out;
        data_in_dram_proc_2 = proc_2_sub_out;
        data_in_dram_proc_3 = proc_3_add_out;
        data_in_dram_proc_4 = proc_4_add_out;
    end
    else if (sm_dur_reg == 3)
        data_in_dram_proc_1 = sm_mult_out;
    else if (sm_dur_reg == 2)
        data_in_dram_proc_2 = sm_mult_out;
    else if (sm_dur_reg == 1)
        data_in_dram_proc_3 = sm_mult_out;
    else if (sm_dur_reg == 0)
        data_in_dram_proc_4 = sm_mult_out;
end

/*-------------------------------------FSM------------------------------------*/

/* Synchronous state update */
always @(posedge clk) begin
    if (rst) begin
        sm_state_reg <= STATE_IDLE;
        sm_round_reg <= 0;
        sm_dur_reg <= 0;
    end
    else begin
        sm_state_reg <= sm_state_new;
        sm_round_reg <= sm_round_new;
        sm_dur_reg <= sm_dur_new;
    end
end

/* Asynchronous next state logic */
always @* begin
    sm_state_new = sm_state_reg;
    sm_round_new = sm_round_reg;
    sm_dur_new = sm_dur_reg - 1'b1;
    idx_reg = 0;

    ready_flag = 0;
    error_flag = 0;

    case (sm_state_reg)
        STATE_IDLE:
            begin
                ready_flag = 1;

                if (sm_ena) begin
                    sm_state_new = STATE_INIT;
                    sm_round_new = sm_round_reg + 1;
                    sm_dur_new = 31;  // just so it's non-zero (then dram4 would we)
                end
            end
        STATE_INIT:
            /* 1 clk */
            begin
                begin
                    sm_state_new = STATE_PHA1;
                end
            end
        STATE_PHA1:
            /* 1 clk */
            begin
                begin
                    sm_state_new = STATE_PHA2;
                    sm_dur_new = 16;
                end
            end
        STATE_PHA2:
            /* 16 clk */
            begin
                if (sm_dur_reg == 0) begin
                    sm_state_new = STATE_PHA3;
                end
            end
        STATE_PHA3:
            /* 1 clk */
            begin
                begin
                    sm_state_new = STATE_PHA4;
                    sm_dur_new = 16;
                end
            end
        STATE_PHA4:
            /* 16 clk */
            begin
                if (sm_dur_reg == 0) begin
                    sm_state_new = STATE_NEXT;
                    sm_round_new = sm_round_reg + 1'b1;
                end
            end
        STATE_NEXT:
            /* 1 clk */
            begin
                if (sm_round_new == 0) begin
                    sm_state_new = STATE_OUTP;
                    sm_dur_new = 16;
                end
                else begin
                    sm_state_new = STATE_PHA1;
                end
            end
        STATE_OUTP:
            /* 1 clk */
            begin
                sm_state_new = STATE_IDLE;
            end
    endcase

    case (sm_round_reg)
        0:  idx_reg = scalar[7:0];
        1:  idx_reg = scalar[15:8];
        2:  idx_reg = scalar[23:16];
        3:  idx_reg = scalar[31:24];
        4:  idx_reg = scalar[39:32];
        5:  idx_reg = scalar[47:40];
        6:  idx_reg = scalar[55:48];
        7:  idx_reg = scalar[63:56];
        8:  idx_reg = scalar[71:64];
        9:  idx_reg = scalar[79:72];
        10: idx_reg = scalar[87:80];
        11: idx_reg = scalar[95:88];
        12: idx_reg = scalar[103:96];
        13: idx_reg = scalar[111:104];
        14: idx_reg = scalar[119:112];
        15: idx_reg = scalar[127:120];
        16: idx_reg = scalar[135:128];
        17: idx_reg = scalar[143:136];
        18: idx_reg = scalar[151:144];
        19: idx_reg = scalar[159:152];
        20: idx_reg = scalar[167:160];
        21: idx_reg = scalar[175:168];
        22: idx_reg = scalar[183:176];
        23: idx_reg = scalar[191:184];
        24: idx_reg = scalar[199:192];
        25: idx_reg = scalar[207:200];
        26: idx_reg = scalar[215:208];
        27: idx_reg = scalar[223:216];
        28: idx_reg = scalar[231:224];
        29: idx_reg = scalar[239:232];
        30: idx_reg = scalar[247:240];
        31: idx_reg = scalar[255:248];
    endcase

end

/*-----------------------------------OUTPUT-----------------------------------*/

always @* begin
    sm_x_out = 255'bx;
    sm_y_out = 255'bx;
    sm_z_out = 255'bx;
    sm_comp_done = 1'b0;
    if (sm_state_reg == STATE_OUTP) begin
        sm_comp_done = 1'b1;
        sm_x_out = data_out_dram_proc_1[254:0];
        sm_y_out = data_out_dram_proc_2[254:0];
        /* z1 was captured at the final PHA4/dur==0 cycle; sm_mult_out no
         * longer holds Z_1 here on real hardware. */
        sm_z_out = z1;
    end
end

endmodule


/* Simple subtraction */
module sub (
    input wire clk,
    input wire rst,

    input wire [254 : 0] sub_in_0,
    input wire [254 : 0] sub_in_1,

    output reg [255 : 0] sub_out
    );

    always @(posedge clk)
        if (rst)
            begin
                sub_out <= 256'b0;
			end
		else
            begin
                // Add the modulus to the first operand to prevent negative values
                sub_out <= 255'h7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed + sub_in_0 - sub_in_1;
			end
endmodule


/* Simple addition */
module add (
    input wire clk,
    input wire rst,

    input wire [254 : 0] add_in_0,
    input wire [254 : 0] add_in_1,

    output reg [255 : 0] add_out
    );

    always @(posedge clk)
        if (rst)
            begin
                add_out <= 256'b0;
			end
		else
            begin
                add_out <= add_in_0 + add_in_1;
			end
endmodule

/* Some small DRAM to save intermediate values during scalar multiplication */
module reg_256 (
   input wire clk,

   input wire en_wr,
   input wire [255:0] data_in,
   output wire [255:0] data_out
);

reg [255:0] inter_data;

always @(posedge clk) begin
    if (en_wr)
        inter_data <= data_in;
end

assign data_out = inter_data;

endmodule


module invert (
    input wire clk,
    input wire rst,

    /* We will invert z and output (x*inv(z), y*inv(z)) */
    input wire [254:0] inv_x,
    input wire [254:0] inv_y,
    input wire [254:0] inv_z,

    /* Control signals */
    input wire inv_ena,
    output reg inv_ready,
    output reg inv_comp_done,

    /* Results from the dedicated multiplier */
    input wire [254 : 0] inv_mult_out,

    /* To the multiplier */
    output reg [255 : 0] inv_mult_in_0,
    output reg [255 : 0] inv_mult_in_1,

    /* Output point x and y */
    output reg [254:0] inv_x_out,
    output reg [254:0] inv_y_out
    );

/*---------------------------INTERNAL CONSTANTS-------------------------------*/

localparam [3:0] ADDR_Z        = 4'd0;
localparam [3:0] ADDR_Z2       = 4'd1;
localparam [3:0] ADDR_Z9       = 4'd2;
localparam [3:0] ADDR_Z11      = 4'd3;
localparam [3:0] ADDR_Z2_5_0   = 4'd4;
localparam [3:0] ADDR_Z2_10_0  = 4'd5;
localparam [3:0] ADDR_Z2_20_0  = 4'd6;
localparam [3:0] ADDR_Z2_50_0  = 4'd7;
localparam [3:0] ADDR_Z2_100_0 = 4'd8;
localparam [3:0] ADDR_INVZ     = 4'd9;
localparam [3:0] ADDR_INVX     = 4'd10;

/*-----------------------------------SIGNALS----------------------------------*/

reg [5:0] inv_state_reg, inv_state_new;
reg [3:0] n_counter, n_counter_next;
reg [6:0] r_counter, r_counter_next;

reg [3:0] addr_in_bram;
reg [3:0] addr_out_bram;

wire we_bram;
wire [254:0] data_out_bram;
/*--------------------------------COMPONENTS----------------------------------*/

bram_255 bram (
    .clk(clk),
    .we(we_bram),
    .addr_in(addr_in_bram),
    .addr_out(addr_out_bram),
    .data_in(inv_mult_out),
    .data_out(data_out_bram)
    );

/*------------------------------------PARAM-----------------------------------*/

localparam [254:0] p          =
    255'h7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed;
localparam [5:0] idle         = 6'd0;
localparam [5:0] s_z2         = 6'd1;
localparam [5:0] s_z4         = 6'd2;
localparam [5:0] s_z8         = 6'd3;
localparam [5:0] s_z9         = 6'd4;
localparam [5:0] s_z11        = 6'd5;
localparam [5:0] s_z22        = 6'd6;
localparam [5:0] s_z2_5_0     = 6'd7;
localparam [5:0] s_z2_6_1     = 6'd8;
localparam [5:0] s_z2_10_5    = 6'd9;
localparam [5:0] s_z2_10_0    = 6'd10;
localparam [5:0] s_z2_11_1    = 6'd11;
localparam [5:0] s_z2_20_10   = 6'd12;
localparam [5:0] s_z2_20_0    = 6'd13;
localparam [5:0] s_z2_21_1    = 6'd14;
localparam [5:0] s_z2_40_20   = 6'd15;
localparam [5:0] s_z2_40_0    = 6'd16;
localparam [5:0] s_z2_41_1    = 6'd17;
localparam [5:0] s_z2_50_10   = 6'd18;
localparam [5:0] s_z2_50_0    = 6'd19;
localparam [5:0] s_z2_51_1    = 6'd20;
localparam [5:0] s_z2_100_50  = 6'd21;
localparam [5:0] s_z2_100_0   = 6'd22;
localparam [5:0] s_z2_101_1   = 6'd23;
localparam [5:0] s_z2_200_100 = 6'd24;
localparam [5:0] s_z2_200_0   = 6'd25;
localparam [5:0] s_z2_201_1   = 6'd26;
localparam [5:0] s_z2_250_50  = 6'd27;
localparam [5:0] s_z2_250_0   = 6'd28;
localparam [5:0] s_z2_251_1   = 6'd29;
localparam [5:0] s_z2_252_2   = 6'd30;
localparam [5:0] s_z2_253_3   = 6'd31;
localparam [5:0] s_z2_254_4   = 6'd32;
localparam [5:0] s_z2_255_5   = 6'd33;
localparam [5:0] s_z2_255_21  = 6'd34;
localparam [5:0] s_invert_x   = 6'd35;
localparam [5:0] s_invert_y   = 6'd36;
localparam [5:0] s_output     = 6'd37;  // output

/*------------------------------------MATHS-----------------------------------*/

/* Invert z */
always @* begin
    /* Defaults */
    inv_mult_in_0 = 256'bx;
    inv_mult_in_1 = 256'bx;
    inv_mult_in_0 = 256'bx;
    inv_mult_in_1 = 256'bx;
    /* Compute x^(2^255 - 21) following the addition chain in the reference
    * implementation */
    if  (inv_state_reg == s_z2) begin
        inv_mult_in_0 = inv_z;                       // z
        inv_mult_in_1 = inv_z;                       // z
    end
    /* Squarings */
    else if  ((inv_state_reg == s_z4)
                || (inv_state_reg == s_z8)
                || (inv_state_reg == s_z22)
                || (inv_state_reg == s_z2_6_1)
                || (inv_state_reg == s_z2_10_5)
                || (inv_state_reg == s_z2_11_1)
                || (inv_state_reg == s_z2_20_10)
                || (inv_state_reg == s_z2_21_1)
                || (inv_state_reg == s_z2_40_20)
                || (inv_state_reg == s_z2_41_1)
                || (inv_state_reg == s_z2_50_10)
                || (inv_state_reg == s_z2_51_1)
                || (inv_state_reg == s_z2_100_50)
                || (inv_state_reg == s_z2_101_1)
                || (inv_state_reg == s_z2_200_100)
                || (inv_state_reg == s_z2_201_1)
                || (inv_state_reg == s_z2_250_50)
                || (inv_state_reg == s_z2_251_1)
                || (inv_state_reg == s_z2_252_2)
                || (inv_state_reg == s_z2_253_3)
                || (inv_state_reg == s_z2_254_4)
                || (inv_state_reg == s_z2_255_5)) begin
        inv_mult_in_0 = inv_mult_out;
        inv_mult_in_1 = inv_mult_out;
    end
    else if  (inv_state_reg == s_z9) begin
        inv_mult_in_0 = inv_mult_out;         // z8
        inv_mult_in_1 = inv_z;                // z
    end
    else if  (inv_state_reg == s_z11) begin
        inv_mult_in_0 = inv_mult_out;         // z9
        inv_mult_in_1 = data_out_bram;        // z2
    end
    else if  (inv_state_reg == s_z2_5_0) begin
        inv_mult_in_0 = inv_mult_out;         // z22
        inv_mult_in_1 = data_out_bram;        // z9
    end
    else if  (inv_state_reg == s_z2_10_0) begin
        inv_mult_in_0 = inv_mult_out;         // z2_10_5
        inv_mult_in_1 = data_out_bram;        // z2_5_0
    end
    else if  (inv_state_reg == s_z2_20_0) begin
        inv_mult_in_0 = inv_mult_out;         // z2_20_10
        inv_mult_in_1 = data_out_bram;        // z2_10_0
    end
    else if  (inv_state_reg == s_z2_40_0) begin
        inv_mult_in_0 = inv_mult_out;         // z2_40_20
        inv_mult_in_1 = data_out_bram;        // z2_20_0
    end
    else if  (inv_state_reg == s_z2_50_0) begin
        inv_mult_in_0 = inv_mult_out;         // z2_50_10
        inv_mult_in_1 = data_out_bram;        // z2_10_0
    end
    else if  (inv_state_reg == s_z2_100_0) begin
        inv_mult_in_0 = inv_mult_out;         // z2_100_50
        inv_mult_in_1 = data_out_bram;        // z2_50_0
    end
    else if  (inv_state_reg == s_z2_200_0) begin
        inv_mult_in_0 = inv_mult_out;         // z2_200_100
        inv_mult_in_1 = data_out_bram;        // z2_100_0
    end
    else if  (inv_state_reg == s_z2_250_0) begin
        inv_mult_in_0 = inv_mult_out;         // z2_250_50
        inv_mult_in_1 = data_out_bram;        // z2_50_0
    end
    else if  (inv_state_reg == s_z2_255_21) begin
        inv_mult_in_0 = inv_mult_out;         // z2_255_5
        inv_mult_in_1 = data_out_bram;        // z11
    end
    else if  (inv_state_reg == s_invert_x) begin
        inv_mult_in_0 = inv_mult_out;         // inv(z)
        inv_mult_in_1 = inv_x;                // x
    end
    else if  (inv_state_reg == s_invert_y) begin
        inv_mult_in_0 = data_out_bram;        // inv(z)
        inv_mult_in_1 = inv_y;                // y
    end
end

/*-------------------------------------FSM------------------------------------*/

/* Synchronous state update */
always @(posedge clk) begin
    if (rst) begin
        n_counter <= 4'd0;
        inv_state_reg <= idle;
    end
    else begin
        n_counter <= n_counter_next;
        r_counter <= r_counter_next;
        inv_state_reg <= inv_state_new;
    end
end

/* Asynchronous next state logic */
always @* begin
    /* No change is the default */
    inv_state_new = inv_state_reg;
    r_counter_next = r_counter;
    /* It takes 13 cycles for a mult result to be available */
    n_counter_next = (n_counter == 4'd0) ? 4'd12 : n_counter - 1'b1;

    /* Only ready when idle */
    inv_ready = 1'b0;

    addr_in_bram = 4'b0;
    addr_out_bram = 4'b0;

    case (inv_state_reg)
    idle:
        begin
            inv_ready = 1'b1;
            if (inv_ena)
                begin
                    inv_state_new = s_z2;
                    n_counter_next = 4'd13;
                end
        end
    s_z2:
        begin
            if (n_counter == 4'b0) begin
                inv_state_new = s_z4;
            end
        end
    s_z4:
        begin
            addr_in_bram = ADDR_Z2;
            if (n_counter == 4'b0) begin
                inv_state_new = s_z8;
            end
        end
    s_z8:
        begin
            if (n_counter == 4'b0) begin
                inv_state_new = s_z9;
            end
        end
    s_z9:
        begin
            if (n_counter == 4'b0) begin
                inv_state_new = s_z11;
                addr_out_bram = ADDR_Z2;
            end
        end
    s_z11:
        begin
            addr_in_bram = ADDR_Z9;
            addr_out_bram = ADDR_Z2;
            if (n_counter == 4'b0) begin
                inv_state_new = s_z22;
            end
        end
    s_z22:
        begin
            addr_in_bram = ADDR_Z11;
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_5_0;
                addr_out_bram = ADDR_Z9;
            end
        end
    s_z2_5_0:
        begin
            addr_out_bram = ADDR_Z9;
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_6_1;
            end
        end
    s_z2_6_1:
        begin
            addr_in_bram = ADDR_Z2_5_0;
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_10_5;
                r_counter_next = 7'd3;
            end
        end
    s_z2_10_5:
        begin
            if (n_counter == 4'b0) begin
                r_counter_next = r_counter - 1'b1;
                if (r_counter == 7'd0) begin
                    inv_state_new = s_z2_10_0;
                    addr_out_bram = ADDR_Z2_5_0;
                end
            end
        end
    s_z2_10_0:
        begin
            addr_out_bram = ADDR_Z2_5_0;
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_11_1;
            end
        end
    s_z2_11_1:
        begin
            addr_in_bram = ADDR_Z2_10_0;
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_20_10;
                r_counter_next = 7'd8;
            end
        end
    s_z2_20_10:
        begin
            if (n_counter == 4'b0) begin
                r_counter_next = r_counter - 1'b1;
                if (r_counter == 7'd0) begin
                    inv_state_new = s_z2_20_0;
                    addr_out_bram = ADDR_Z2_10_0;
                end
            end
        end
    s_z2_20_0:
        begin
            addr_out_bram = ADDR_Z2_10_0;
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_21_1;
            end
        end
    s_z2_21_1:
        begin
            addr_in_bram = ADDR_Z2_20_0;
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_40_20;
                r_counter_next = 7'd18;
            end
        end
    s_z2_40_20:
        begin
            if (n_counter == 4'b0) begin
                r_counter_next = r_counter - 1'b1;
                if (r_counter == 7'd0) begin
                    inv_state_new = s_z2_40_0;
                    addr_out_bram = ADDR_Z2_20_0;
                end
            end
        end
    s_z2_40_0:
        begin
            addr_out_bram = ADDR_Z2_20_0;
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_41_1;
            end
        end
    s_z2_41_1:
        begin
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_50_10;
                r_counter_next = 7'd8;
            end
        end
    s_z2_50_10:
        begin
            if (n_counter == 4'b0) begin
                r_counter_next = r_counter - 1'b1;
                if (r_counter == 7'd0) begin
                    inv_state_new = s_z2_50_0;
                    addr_out_bram = ADDR_Z2_10_0;
                end
            end
        end
    s_z2_50_0:
        begin
            addr_out_bram = ADDR_Z2_10_0;
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_51_1;
            end
        end
    s_z2_51_1:
        begin
            addr_in_bram = ADDR_Z2_50_0;
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_100_50;
                r_counter_next = 7'd48;
            end
        end
    s_z2_100_50:
        begin
            if (n_counter == 4'b0) begin
                r_counter_next = r_counter - 1'b1;
                if (r_counter == 7'd0) begin
                    inv_state_new = s_z2_100_0;
                    addr_out_bram = ADDR_Z2_50_0;
                end
            end
        end
    s_z2_100_0:
        begin
            addr_out_bram = ADDR_Z2_50_0;
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_101_1;
            end
        end
    s_z2_101_1:
        begin
            addr_in_bram = ADDR_Z2_100_0;
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_200_100;
                r_counter_next = 7'd98;
            end
        end
    s_z2_200_100:
        begin
            if (n_counter == 4'b0) begin
                r_counter_next = r_counter - 1'b1;
                if (r_counter == 7'd0) begin
                    inv_state_new = s_z2_200_0;
                    addr_out_bram = ADDR_Z2_100_0;
                end
            end
        end
    s_z2_200_0:
        begin
            addr_out_bram = ADDR_Z2_100_0;
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_201_1;
            end
        end
    s_z2_201_1:
        begin
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_250_50;
                r_counter_next = 7'd48;
            end
        end
    s_z2_250_50:
        begin
            if (n_counter == 4'b0) begin
                r_counter_next = r_counter - 1'b1;
                if (r_counter == 7'd0) begin
                    inv_state_new = s_z2_250_0;
                    addr_out_bram = ADDR_Z2_50_0;
                end
            end
        end
    s_z2_250_0:
        begin
            addr_out_bram = ADDR_Z2_50_0;
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_251_1;
            end
        end
    s_z2_251_1:
        begin
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_252_2;
            end
        end
    s_z2_252_2:
        begin
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_253_3;
            end
        end
    s_z2_253_3:
        begin
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_254_4;
            end
        end
    s_z2_254_4:
        begin
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_255_5;
            end
        end
    s_z2_255_5:
        begin
            if (n_counter == 4'b0) begin
                inv_state_new = s_z2_255_21;
                addr_out_bram = ADDR_Z11;
            end
        end
    s_z2_255_21:
        begin
            addr_out_bram = ADDR_Z11;
            if (n_counter == 4'b0) begin
                inv_state_new = s_invert_x;
            end
        end
    s_invert_x:
        begin
            addr_in_bram = ADDR_INVZ;
            if (n_counter == 4'b0) begin
                inv_state_new = s_invert_y;
                addr_out_bram = ADDR_INVZ;
            end
        end
    s_invert_y:
        begin
            addr_in_bram = ADDR_INVX;
            addr_out_bram = ADDR_INVZ;
            if (n_counter == 4'b0) begin
                inv_state_new = s_output;
                addr_out_bram = ADDR_INVX;
            end
        end
    s_output:
        begin
            inv_state_new = idle;
        end
    default:
        begin
            inv_state_new = idle;
        end
    endcase
end

/*---------------------------------REG UPDATE---------------------------------*/

assign we_bram = (inv_state_reg == s_z4)
               | (inv_state_reg == s_z11)
               | (inv_state_reg == s_z22)
               | (inv_state_reg == s_z2_6_1)
               | (inv_state_reg == s_z2_11_1)
               | (inv_state_reg == s_z2_21_1)
               | (inv_state_reg == s_z2_51_1)
               | (inv_state_reg == s_z2_101_1)
               | (inv_state_reg == s_invert_x)
               | (inv_state_reg == s_invert_y);

/*-----------------------------------OUTPUT-----------------------------------*/

/* Output the affine coordinates */
always @* begin
    inv_x_out = 255'bx;
    inv_y_out = 255'bx;
    inv_comp_done = 1'b0;
    if (inv_state_reg == s_output) begin
        inv_comp_done = 1'b1;
        // TODO Optimize conditional output (need this fully reduced)
        inv_x_out = data_out_bram < p ? data_out_bram :
            data_out_bram - p;
        inv_y_out = inv_mult_out < p ? inv_mult_out :
            inv_mult_out - p;
    end
end

endmodule


/* Reduce a 512 bit number mod 2**252
*                               + 27742317777372353535851937790883648493 */

module barrett_reduce (
    input wire clk,
    input wire rst,

    /* We will take a 512 bit number and reduce it modulo l */
    input wire [511:0] red_in,

    /* Control signals */
    input wire red_ena,
    output reg red_ready,
    output reg red_comp_done,

    /* Results from the dedicated multipliers */
    input wire [511 : 0] red_mult_out_512,

    /* To the multipliers */
    output reg [255 : 0] red_mult_in_0,
    output reg [255 : 0] red_mult_in_1,

    /* It is done */
    output reg [252:0] red_out
    );

/*---------------------------INTERNAL CONSTANTS-------------------------------*/

/* For barrett reduction */
/* 2**252 + 27742317777372353535851937790883648493 */
localparam m =
    253'h1000000000000000000000000000000014def9dea2f79cd65812631a5cf5d3ed;
/* 4**256 / m */
localparam mu =
    260'hfffffffffffffffffffffffffffffffeb2106215d086329a7ed9ce5a30a2c131b;

localparam [3:0] STATE_IDLE         = 4'd0;
localparam [3:0] STATE_LONG_MULT_1  = 4'd1;
localparam [3:0] STATE_LONG_MULT_2  = 4'd2;
localparam [3:0] STATE_LONG_MULT_3  = 4'd3;
localparam [3:0] STATE_LONG_MULT_4  = 4'd4;
localparam [3:0] STATE_ADD          = 4'd5;
localparam [3:0] STATE_SHORT_MULT   = 4'd6;
localparam [3:0] STATE_SUB          = 4'd7;
localparam [3:0] STATE_SAVE_SUB     = 4'd8;
localparam [3:0] STATE_SAVE_COMPARE = 4'd9;
localparam [3:0] STATE_OUTPUT       = 4'd10;
localparam [3:0] STATE_DONE         = 4'd11;

/*------------------------------------REGS------------------------------------*/

reg [3:0] red_state_reg;
reg [3:0] red_state_new;

reg [3:0] n_counter_reg;
reg [3:0] n_counter_new;

reg compare_flag_reg;
reg compare_flag_new;

reg [515:0] layer_0_reg_00;
reg [515:0] layer_0_reg_01;
reg [515:0] layer_0_reg_02;
reg [515:0] layer_0_reg_03;
reg [253:0] sub_in_0;
reg [253:0] sub_in_1;

/*-----------------------------------WIRES------------------------------------*/

wire [515:0] layer_1_wire_00;
wire [515:0] layer_1_wire_01;
wire [515:0] layer_2_wire_00;
wire [253:0] sub_out;

wire en_wr_bram_1;
wire en_wr_bram_2;
wire en_wr_bram_3;

wire we_bram_c1;
wire we_bram_c2;

wire [511:0] data_in_bram_1;
wire [511:0] data_in_bram_2;
wire [511:0] data_in_bram_3;

wire [511:0] data_out_bram_1;
wire [511:0] data_out_bram_2;
wire [511:0] data_out_bram_3;
wire [252:0] data_out_bram_c1;
wire [252:0] data_out_bram_c2;

/*--------------------------------COMPONENTS----------------------------------*/

add_516 layer_1_0 (
    .clk(clk),
    .rst(rst),
    .add_in0(layer_0_reg_00),
    .add_in1(layer_0_reg_01),
    .add_out(layer_1_wire_00)
);

add_516 layer_1_1 (
    .clk(clk),
    .rst(rst),
    .add_in0(layer_0_reg_02),
    .add_in1(layer_0_reg_03),
    .add_out(layer_1_wire_01)
);

add_516 layer_2_1 (
    .clk(clk),
    .rst(rst),
    .add_in0(layer_1_wire_00),
    .add_in1(layer_1_wire_01),
    .add_out(layer_2_wire_00)
);

sub_254 sub_0 (
    .clk(clk),
    .rst(rst),
    .sub_in0(sub_in_0),
    .sub_in1(sub_in_1),
    .sub_out(sub_out)
);

bram_512 bram_1 (
    .clk(clk),
    .we(en_wr_bram_1),
    .addr(3'b0),
    .data_in(data_in_bram_1),
    .data_out(data_out_bram_1)
    );

bram_512 bram_2 (
    .clk(clk),
    .we(en_wr_bram_2),
    .addr(3'b0),
    .data_in(data_in_bram_2),
    .data_out(data_out_bram_2)
    );

bram_512 bram_3 (
    .clk(clk),
    .we(en_wr_bram_3),
    .addr(3'b0),
    .data_in(data_in_bram_3),
    .data_out(data_out_bram_3)
    );

bram_253 bram_c1 (
    .clk(clk),
    .we(we_bram_c1),
    .addr(1'b0),
    .data_in(sub_out),
    .data_out(data_out_bram_c1)
    );

bram_253 bram_c2 (
    .clk(clk),
    .we(we_bram_c2),
    .addr(1'b0),
    .data_in(sub_out),
    .data_out(data_out_bram_c2)
    );

/*------------------------------------MATH------------------------------------*/

always @* begin
    red_mult_in_0 = 256'b0;
    red_mult_in_1 = 256'b0;

    layer_0_reg_00 = 516'b0;
    layer_0_reg_01 = 516'b0;
    layer_0_reg_02 = 516'b0;
    layer_0_reg_03 = 516'b0;

    sub_in_0 = 254'b0;
    sub_in_1 = 254'b0;

    /* t = x - ((x*mu) >> (2*k)) * n */
    /* x:  512 bit */
    /* mu: 260 bit */
    /* n:  253 bit */
    /* We can split x*mu over 4 multiplications */
    if (red_state_reg == STATE_LONG_MULT_1) begin
        red_mult_in_0 = red_in[255:0];
        red_mult_in_1 = mu[255:0];
    end

    if (red_state_reg == STATE_LONG_MULT_2) begin
        red_mult_in_0 = red_in[511:256];
        red_mult_in_1 = mu[255:0];
    end

    if (red_state_reg == STATE_LONG_MULT_3) begin
        red_mult_in_0 = red_in[255:0];
        red_mult_in_1 = mu[259:256];
    end

    if (red_state_reg == STATE_LONG_MULT_4) begin
        red_mult_in_0 = red_in[511:256];
        red_mult_in_1 = mu[259:256];
    end

    /* x*mu fits in 772 bits, we do not need the bottom 256 bits */
    if (red_state_reg == STATE_ADD) begin
        /* Already throw out the 256 lsb */
        layer_0_reg_00 = data_out_bram_1[511:256];
        layer_0_reg_01 = data_out_bram_2;

        layer_0_reg_02 = data_out_bram_3;
        layer_0_reg_03 = {red_mult_out_512[259:0], 256'b0};
    end
    if (red_state_reg == STATE_SHORT_MULT) begin
        /* We have 260 bits on layer2, but we only need the the bottom 254 of
        * the result so it's ok */
        red_mult_in_0 = layer_2_wire_00[511:256];
        red_mult_in_1 = m;
    end
    if (red_state_reg == STATE_SUB) begin
        /* We only need to subtract the 254 lsb */
        sub_in_0 = red_in[253:0];
        sub_in_1 = red_mult_out_512[253:0];
    end
    /* save result 1 and start second substraction */
    if (red_state_reg == STATE_SAVE_SUB) begin
        sub_in_0 = sub_out;
        sub_in_1 = m;
    end
    /* Compare result 1 and save result 2 */
    if (red_state_reg == STATE_SAVE_COMPARE) begin
    end
    /* Conditionally output one of the results */
    if (red_state_reg == STATE_OUTPUT) begin
    end
end
/*-------------------------------------FSM------------------------------------*/

/* Synchronous state update */
always @(posedge clk) begin
    if (rst) begin
        red_state_reg <= STATE_IDLE;
        n_counter_reg <= 4'b0;
    end
    else begin
        red_state_reg <= red_state_new;
        n_counter_reg <= n_counter_new;
    end
end

/* Asynchronous next state logic */
always @* begin
    /* No change is the default */
    red_state_new = red_state_reg;
    /* Only ready when idle */
    red_ready = 1'b0;
    n_counter_new = (n_counter_reg - 1'b1);

    case (red_state_reg)
        STATE_IDLE:
            begin
                red_ready = 1'b1;
                if (red_ena)
                    begin
                        red_state_new = STATE_LONG_MULT_1;
                        n_counter_new = 4'd9;
                    end
            end
        STATE_LONG_MULT_1:
            begin
                if (n_counter_reg == 4'b0) begin
                    red_state_new = STATE_LONG_MULT_2;
                    n_counter_new = 4'd9;
                end
            end
        STATE_LONG_MULT_2:
            begin
                if (n_counter_reg == 4'b0) begin
                    red_state_new = STATE_LONG_MULT_3;
                    n_counter_new = 4'd9;
                end
            end
        STATE_LONG_MULT_3:
            begin
                if (n_counter_reg == 4'b0) begin
                    red_state_new = STATE_LONG_MULT_4;
                    n_counter_new = 4'd9;
                end
            end
        STATE_LONG_MULT_4:
            begin
                if (n_counter_reg == 4'b0) begin
                    red_state_new = STATE_ADD;
                    n_counter_new = 4'd1;
                end
            end
        STATE_ADD:
            begin
                if (n_counter_reg == 4'b0) begin
                    red_state_new = STATE_SHORT_MULT;
                    n_counter_new = 4'd9;
                end
            end
        STATE_SHORT_MULT:
            begin
                if (n_counter_reg == 4'b0) begin
                    red_state_new = STATE_SUB;
                end
            end
        STATE_SUB:
            begin
                red_state_new = STATE_SAVE_SUB;
            end
        STATE_SAVE_SUB:
            begin
                red_state_new = STATE_SAVE_COMPARE;
            end
        STATE_SAVE_COMPARE:
            begin
                red_state_new = STATE_OUTPUT;
            end
        STATE_OUTPUT:
            begin
                red_state_new = STATE_IDLE;
            end
        default:
            red_state_new = STATE_IDLE;
    endcase
end

/*------------------------------------RAM-------------------------------------*/

assign en_wr_bram_1 = (red_state_reg == STATE_LONG_MULT_2);
assign en_wr_bram_2 = (red_state_reg == STATE_LONG_MULT_3);
assign en_wr_bram_3 = (red_state_reg == STATE_LONG_MULT_4);
assign we_bram_c1 = (red_state_reg == STATE_SAVE_SUB);
assign we_bram_c2 = (red_state_reg == STATE_SAVE_COMPARE);

assign data_in_bram_1 = red_mult_out_512;
assign data_in_bram_2 = red_mult_out_512;
assign data_in_bram_3 = red_mult_out_512;

always @(posedge clk) begin
    if (rst) begin
        compare_flag_reg <= 1'b0;
    end
    else begin
        compare_flag_reg <= compare_flag_new;
    end
end

always @* begin
    compare_flag_new = compare_flag_reg;

    if (red_state_reg == STATE_SAVE_COMPARE) begin
        compare_flag_new = (data_out_bram_c1 > m);
    end
end

/*-----------------------------------OUTPUT-----------------------------------*/
always @* begin
    red_out = 253'bx;
    red_comp_done = 1'b0;
    if (red_state_reg == STATE_OUTPUT) begin
        red_comp_done = 1'b1;
        red_out = compare_flag_reg ? data_out_bram_c2 : data_out_bram_c1;
    end
end

endmodule


module add_516 (
    input wire clk,
    input wire rst,

    input wire [515 : 0] add_in0,
    input wire [515 : 0] add_in1,

    output reg [515 : 0] add_out
    );

    always @(posedge clk)
        if (rst)
            begin
                add_out <= 516'b0;
			end
		else
            begin
                add_out <= add_in0 + add_in1;
			end
endmodule


module sub_254 (
    input wire clk,
    input wire rst,

    input wire [253 : 0] sub_in0,
    input wire [253 : 0] sub_in1,

    output reg [253 : 0] sub_out
    );

    always @(posedge clk)
        if (rst)
            begin
                sub_out <= 254'b0;
			end
		else
            begin
                sub_out <= sub_in0 - sub_in1;
			end
endmodule