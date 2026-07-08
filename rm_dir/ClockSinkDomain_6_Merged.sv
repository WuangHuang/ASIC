// ==========================================================
// FILE TỔNG HỢP CÓ KIỂM DUYỆT CỦA: ClockSinkDomain_6
// ==========================================================

// --- BẮT ĐẦU FILE: round.v ---
/*
 * Copyright 2013, Homer Hsing <homer.hsing@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

`define low_pos(x,y)        `high_pos(x,y) - 63
`define high_pos(x,y)       1599 - 64*(5*y+x)
`define add_1(x)            (x == 4 ? 0 : x + 1)
`define add_2(x)            (x == 3 ? 0 : x == 4 ? 1 : x + 2)
`define sub_1(x)            (x == 0 ? 4 : x - 1)
`define rot_up(in, n)       {in[63-n:0], in[63:63-n+1]}
`define rot_up_1(in)        {in[62:0], in[63]}

module round(in, round_const, out);
    input  [1599:0] in;
    input  [63:0]   round_const;
    output [1599:0] out;

    wire   [63:0]   a[4:0][4:0];
    wire   [63:0]   b[4:0];
    wire   [63:0]   c[4:0][4:0], d[4:0][4:0], e[4:0][4:0], f[4:0][4:0], g[4:0][4:0];

    genvar x, y;

    /* assign "a[x][y][z] == in[w(5y+x)+z]" */
    generate
      for(y=0; y<5; y=y+1)
        begin : L0
          for(x=0; x<5; x=x+1)
            begin : L1
              assign a[x][y] = in[`high_pos(x,y) : `low_pos(x,y)];
            end
        end
    endgenerate

    /* calc "b[x] == a[x][0] ^ a[x][1] ^ ... ^ a[x][4]" */
    generate
      for(x=0; x<5; x=x+1)
        begin : L2
          assign b[x] = a[x][0] ^ a[x][1] ^ a[x][2] ^ a[x][3] ^ a[x][4];
        end
    endgenerate

    /* calc "c == theta(a)" */
    generate
      for(y=0; y<5; y=y+1)
        begin : L3
          for(x=0; x<5; x=x+1)
            begin : L4
              assign c[x][y] = a[x][y] ^ b[`sub_1(x)] ^ `rot_up_1(b[`add_1(x)]);
            end
        end
    endgenerate

    /* calc "d == rho(c)" */
    assign d[0][0] = c[0][0];
    assign d[1][0] = `rot_up_1(c[1][0]);
    assign d[2][0] = `rot_up(c[2][0], 62);
    assign d[3][0] = `rot_up(c[3][0], 28);
    assign d[4][0] = `rot_up(c[4][0], 27);
    assign d[0][1] = `rot_up(c[0][1], 36);
    assign d[1][1] = `rot_up(c[1][1], 44);
    assign d[2][1] = `rot_up(c[2][1], 6);
    assign d[3][1] = `rot_up(c[3][1], 55);
    assign d[4][1] = `rot_up(c[4][1], 20);
    assign d[0][2] = `rot_up(c[0][2], 3);
    assign d[1][2] = `rot_up(c[1][2], 10);
    assign d[2][2] = `rot_up(c[2][2], 43);
    assign d[3][2] = `rot_up(c[3][2], 25);
    assign d[4][2] = `rot_up(c[4][2], 39);
    assign d[0][3] = `rot_up(c[0][3], 41);
    assign d[1][3] = `rot_up(c[1][3], 45);
    assign d[2][3] = `rot_up(c[2][3], 15);
    assign d[3][3] = `rot_up(c[3][3], 21);
    assign d[4][3] = `rot_up(c[4][3], 8);
    assign d[0][4] = `rot_up(c[0][4], 18);
    assign d[1][4] = `rot_up(c[1][4], 2);
    assign d[2][4] = `rot_up(c[2][4], 61);
    assign d[3][4] = `rot_up(c[3][4], 56);
    assign d[4][4] = `rot_up(c[4][4], 14);

    /* calc "e == pi(d)" */
    assign e[0][0] = d[0][0];
    assign e[0][2] = d[1][0];
    assign e[0][4] = d[2][0];
    assign e[0][1] = d[3][0];
    assign e[0][3] = d[4][0];
    assign e[1][3] = d[0][1];
    assign e[1][0] = d[1][1];
    assign e[1][2] = d[2][1];
    assign e[1][4] = d[3][1];
    assign e[1][1] = d[4][1];
    assign e[2][1] = d[0][2];
    assign e[2][3] = d[1][2];
    assign e[2][0] = d[2][2];
    assign e[2][2] = d[3][2];
    assign e[2][4] = d[4][2];
    assign e[3][4] = d[0][3];
    assign e[3][1] = d[1][3];
    assign e[3][3] = d[2][3];
    assign e[3][0] = d[3][3];
    assign e[3][2] = d[4][3];
    assign e[4][2] = d[0][4];
    assign e[4][4] = d[1][4];
    assign e[4][1] = d[2][4];
    assign e[4][3] = d[3][4];
    assign e[4][0] = d[4][4];

    /* calc "f = chi(e)" */
    generate
      for(y=0; y<5; y=y+1)
        begin : L5
          for(x=0; x<5; x=x+1)
            begin : L6
              assign f[x][y] = e[x][y] ^ ((~ e[`add_1(x)][y]) & e[`add_2(x)][y]);
            end
        end
    endgenerate

    /* calc "g = iota(f)" */
    generate
      for(x=0; x<64; x=x+1)
        begin : L60
          if(x==0 || x==1 || x==3 || x==7 || x==15 || x==31 || x==63)
            assign g[0][0][x] = f[0][0][x] ^ round_const[x];
          else
            assign g[0][0][x] = f[0][0][x];
        end
    endgenerate
    
    generate
      for(y=0; y<5; y=y+1)
        begin : L7
          for(x=0; x<5; x=x+1)
            begin : L8
              if(x!=0 || y!=0)
                assign g[x][y] = f[x][y];
            end
        end
    endgenerate

    /* assign "out[w(5y+x)+z] == out_var[x][y][z]" */
    generate
      for(y=0; y<5; y=y+1)
        begin : L99
          for(x=0; x<5; x=x+1)
            begin : L100
              assign out[`high_pos(x,y) : `low_pos(x,y)] = g[x][y];
            end
        end
    endgenerate
endmodule

`undef low_pos
`undef high_pos
`undef add_1
`undef add_2
`undef sub_1
`undef rot_up
`undef rot_up_1
// --- KẾT THÚC FILE: round.v ---

// --- BẮT ĐẦU FILE: rconst.v ---
/*
 * Copyright 2013, Homer Hsing <homer.hsing@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* round constant */
module rconst(i, rc);
    input      [23:0] i;
    output reg [63:0] rc;
    
    always @ (i)
      begin
        rc = 0;
        rc[0] = i[0] | i[4] | i[5] | i[6] | i[7] | i[10] | i[12] | i[13] | i[14] | i[15] | i[20] | i[22];
        rc[1] = i[1] | i[2] | i[4] | i[8] | i[11] | i[12] | i[13] | i[15] | i[16] | i[18] | i[19];
        rc[3] = i[2] | i[4] | i[7] | i[8] | i[9] | i[10] | i[11] | i[12] | i[13] | i[14] | i[18] | i[19] | i[23];
        rc[7] = i[1] | i[2] | i[4] | i[6] | i[8] | i[9] | i[12] | i[13] | i[14] | i[17] | i[20] | i[21];
        rc[15] = i[1] | i[2] | i[3] | i[4] | i[6] | i[7] | i[10] | i[12] | i[14] | i[15] | i[16] | i[18] | i[20] | i[21] | i[23];
        rc[31] = i[3] | i[5] | i[6] | i[10] | i[11] | i[12] | i[19] | i[20] | i[22] | i[23];
        rc[63] = i[2] | i[3] | i[6] | i[7] | i[13] | i[14] | i[15] | i[16] | i[17] | i[19] | i[20] | i[21] | i[23];
      end
endmodule

// --- KẾT THÚC FILE: rconst.v ---

// --- BẮT ĐẦU FILE: padder1.v ---
/*
 * Copyright 2013, Homer Hsing <homer.hsing@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 *     in      byte_num     out
 * 0x11223344      0    0x01000000
 * 0x11223344      1    0x11010000
 * 0x11223344      2    0x11220100
 * 0x11223344      3    0x11223301
 */

module padder1(in, byte_num, out);
    input      [31:0] in;
    input      [1:0]  byte_num;
    output reg [31:0] out;
    
    always @ (*)
      case (byte_num)
//        0: out = 32'h1000000;
//        1: out = {in[31:24], 24'h010000};
//        2: out = {in[31:16], 16'h0100};
//        3: out = {in[31:8],   8'h01};
		  
		0: out = 32'h6000000;
		1: out = {in[31:24], 24'h060000};
		2: out = {in[31:16], 16'h0600};
		3: out = {in[31:8],   8'h06};
	endcase
endmodule
// --- KẾT THÚC FILE: padder1.v ---

// --- BẮT ĐẦU FILE: f_permutation.v ---
/*
 * Copyright 2013, Homer Hsing <homer.hsing@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* if "ack" is 1, then current input has been used. */

module f_permutation(clk, reset, in, in_ready, ack, out, out_ready);
    input               clk, reset;
    input      [575:0]  in;
    input               in_ready;
    output              ack;
    output reg [1599:0] out;
    output reg          out_ready;

    reg        [22:0]   i; /* select round constant */
    wire       [1599:0] round_in, round_out;
    wire       [63:0]   rc; /* round constant */
    wire                update;
    wire                accept;
    reg                 calc; /* == 1: calculating rounds */

    assign accept = in_ready & (~ calc); // in_ready & (i == 0)
    
    always @ (posedge clk)
      if (reset) i <= 0;
      else       i <= {i[21:0], accept};
    
    always @ (posedge clk)
      if (reset) calc <= 0;
      else       calc <= (calc & (~ i[22])) | accept;
    
    assign update = calc | accept;

    assign ack = accept;

    always @ (posedge clk)
      if (reset)
        out_ready <= 0;
      else if (accept)
        out_ready <= 0;
      else if (i[22]) // only change at the last round
        out_ready <= 1;

    assign round_in = accept ? {in ^ out[1599:1599-575], out[1599-576:0]} : out;

    rconst
      rconst_ ({i, accept}, rc);

    round
      round_ (round_in, rc, round_out);

    always @ (posedge clk)
      if (reset)
        out <= 0;
      else if (update)
        out <= round_out;
endmodule
// --- KẾT THÚC FILE: f_permutation.v ---

// --- BẮT ĐẦU FILE: padder.v ---
/*
 * Copyright 2013, Homer Hsing <homer.hsing@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* "is_last" == 0 means byte number is 4, no matter what value "byte_num" is. */
/* if "in_ready" == 0, then "is_last" should be 0. */
/* the user switch to next "in" only if "ack" == 1. */

module padder(clk, reset, in, in_ready, is_last, byte_num, buffer_full, out, out_ready, f_ack);
    input              clk, reset;
    input      [31:0]  in;
    input              in_ready, is_last;
    input      [1:0]   byte_num;
    output             buffer_full; /* to "user" module */
    output reg [575:0] out;         /* to "f_permutation" module */
    output             out_ready;   /* to "f_permutation" module */
    input              f_ack;       /* from "f_permutation" module */
    
    reg                state;       /* state == 0: user will send more input data
                                     * state == 1: user will not send any data */
    reg                done;        /* == 1: out_ready should be 0 */
    reg        [17:0]  i;           /* length of "out" buffer */
    wire       [31:0]  v0;          /* output of module "padder1" */
    reg        [31:0]  v1;          /* to be shifted into register "out" */
    wire               accept,      /* accept user input? */
                       update;
    
    assign buffer_full = i[17];
    assign out_ready = buffer_full;
    assign accept = (~ state) & in_ready & (~ buffer_full); // if state == 1, do not eat input
    assign update = (accept | (state & (~ buffer_full))) & (~ done); // don't fill buffer if done

    always @ (posedge clk)
      if (reset)
        out <= 0;
      else if (update)
        out <= {out[575-32:0], v1};

    always @ (posedge clk)
      if (reset)
        i <= 0;
      else if (f_ack | update)
        i <= {i[16:0], 1'b1} & {18{~ f_ack}};
/*    if (f_ack)  i <= 0; */
/*    if (update) i <= {i[16:0], 1'b1}; // increase length */

    always @ (posedge clk)
      if (reset)
        state <= 0;
      else if (is_last)
        state <= 1;

    always @ (posedge clk)
      if (reset)
        done <= 0;
      else if (state & out_ready)
        done <= 1;

    padder1 p0 (in, byte_num, v0);
    
    always @ (*)
      begin
        if (state)
          begin
            v1 = 0;
            v1[7] = v1[7] | i[16]; // "v1[7]" is the MSB of the last byte of "v1"
          end
        else if (is_last == 0)
          v1 = in;
        else
          begin
            v1 = v0;
            v1[7] = v1[7] | i[16];
          end
      end
endmodule
// --- KẾT THÚC FILE: padder.v ---

// --- BẮT ĐẦU FILE: keccak.v ---
/*
 * Copyright 2013, Homer Hsing <homer.hsing@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* "is_last" == 0 means byte number is 8, no matter what value "byte_num" is. */
/* if "in_ready" == 0, then "is_last" should be 0. */
/* the user switch to next "in" only if "ack" == 1. */

`define low_pos(w,b)      ((w)*64 + (b)*8)
`define low_pos2(w,b)     `low_pos(w,7-b)
`define high_pos(w,b)     (`low_pos(w,b) + 7)
`define high_pos2(w,b)    (`low_pos2(w,b) + 7)

module keccak(clk, reset, in, in_ready, is_last, byte_num, buffer_full, out, out_ready);
    input              clk, reset;
    input      [31:0]  in;
    input              in_ready, is_last;
    input      [1:0]   byte_num;
    output             buffer_full; /* to "user" module */
    output     [511:0] out;
    output reg         out_ready;

    reg                state;     /* state == 0: user will send more input data
                                   * state == 1: user will not send any data */
    wire       [575:0] padder_out,
                       padder_out_1; /* before reorder byte */
    wire               padder_out_ready;
    wire               f_ack;
    wire      [1599:0] f_out;
    wire               f_out_ready;
    wire       [511:0] out1;      /* before reorder byte */
    reg        [22:0]  i;         /* gen "out_ready" */

    genvar w, b;

    assign out1 = f_out[1599:1599-511];

    always @ (posedge clk)
      if (reset)
        i <= 0;
      else
        i <= {i[21:0], state & f_ack};

    always @ (posedge clk)
      if (reset)
        state <= 0;
      else if (is_last)
        state <= 1;

    /* reorder byte ~ ~ */
    generate
      for(w=0; w<8; w=w+1)
        begin : L0
          for(b=0; b<8; b=b+1)
            begin : L1
              assign out[`high_pos(w,b):`low_pos(w,b)] = out1[`high_pos2(w,b):`low_pos2(w,b)];
            end
        end
    endgenerate

    /* reorder byte ~ ~ */
    generate
      for(w=0; w<9; w=w+1)
        begin : L2
          for(b=0; b<8; b=b+1)
            begin : L3
              assign padder_out[`high_pos(w,b):`low_pos(w,b)] = padder_out_1[`high_pos2(w,b):`low_pos2(w,b)];
            end
        end
    endgenerate

    always @ (posedge clk)
      if (reset)
        out_ready <= 0;
      else if (i[22])
        out_ready <= 1;

    padder
      padder_ (clk, reset, in, in_ready, is_last, byte_num, buffer_full, padder_out_1, padder_out_ready, f_ack);

    f_permutation
      f_permutation_ (clk, reset, padder_out, padder_out_ready, f_ack, f_out, f_out_ready);
endmodule

`undef low_pos
`undef low_pos2
`undef high_pos
`undef high_pos2
// --- KẾT THÚC FILE: keccak.v ---

// --- BẮT ĐẦU FILE: keccak_wrapper.v ---
/***************************************************************************************
 * 
 * SHA3-512 wrapper 
 * 
 * Author: Khai Minh Ma
 * 
 ***************************************************************************************/

module keccak_wrapper(
	input	iClk,		
	input	iReset,

	input	iChipSelect,		
	input	iWrite,
	input 	iRead,			

	input [7:0]  	iAddress,
	input [31:0]  	iWriteData,		// Directly connected to keccak

	output reg [31:0]  	oReadData
);


/*****************************************************************************
 *           Internal Wires, Registers and Paramemters Declarations          *
 *****************************************************************************/

// in 			- 32-bit: 	input data MSWord -> LSWord
// in_ready		- 1-bit:	data-in indicator
// is_last		- 1-bit:	data-in is last word indicator
// byte_num		- 2-bit: 	size of the "is_last" data (in bytes) to cut -> "padder1.v"
// buffer_full  - 1-bit: 	buffer is full, begin to hash?
// out 			- 512-bit:	hash output (digest)
// out_ready 	- 1-bit:


reg [31:0]		rKeccak_input;
reg				rKeccak_in_ready;
reg 			rKeccak_is_last;
reg [1:0]		rKeccak_byte_num;

wire [511:0] 	wKeccak_out;
wire 			wKeccak_out_ready;	
wire 			wKeccak_buffer_full;

wire 			wKeccak_in_ready;
wire 			wKeccak_is_last;
wire [1:0]		wKeccak_byte_num;


reg 			rReset_internal;

reg 			rAllow_in_ready;

/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/
keccak DUT(
	.clk 		(iClk), 
	.reset 		(rReset_internal), 

	.in  		(iWriteData), 				// iWriteData or rKeccak_input?
	.in_ready 	(rKeccak_in_ready), 
	.is_last  	(rKeccak_is_last),
	.byte_num 	(rKeccak_byte_num), 

	.buffer_full(wKeccak_buffer_full), 
	.out  		(wKeccak_out), 
	.out_ready  (wKeccak_out_ready)
);



/*****************************************************************************
 *                            Combinational Logic                            *
 *****************************************************************************/

// Temp
// assign oReadData = wKeccak_out[511:(512-32)];




/*****************************************************************************
 *                             Sequential Logic                              *
 *****************************************************************************/
always @(posedge iClk or posedge iReset) 
begin
	if (iReset) 
	begin
		rKeccak_input 		<= 32'h0; // ??????
		rReset_internal 	<= iReset;
		rKeccak_in_ready	<= 1'b0;
		rKeccak_is_last 	<= 1'b0;
		rKeccak_byte_num	<= 2'b00;
	end


	else if (iChipSelect) 
	begin
		rReset_internal 	<= iReset;
		rKeccak_in_ready	<= 1'b0;
		rKeccak_is_last 	<= 1'b0;

		if(iWrite)
		begin
			case(iAddress)
				8'h00:	rReset_internal		<= 1'h1;
				8'h01:
					begin 
						rKeccak_in_ready 	<= 1'b1 & rAllow_in_ready;
						rKeccak_is_last 	<= 1'b0;
					end

				8'h02:	rKeccak_byte_num 	<= iWriteData[1:0];
				8'h03:
					begin
						rKeccak_in_ready 	<= 1'b1 & rAllow_in_ready;
						rKeccak_is_last 	<= 1'b1;
						//rKeccak_byte_num is configured at ADDR 0x02
					end

				default:
					begin
					end

			endcase
		end


		else if(iRead)
		begin
			case(iAddress)
				8'h0f:	oReadData <= {30'h0, wKeccak_buffer_full, wKeccak_out_ready};
				8'h10:	oReadData <= wKeccak_out[511:480];
				8'h11:	oReadData <= wKeccak_out[479:448];
				8'h12:	oReadData <= wKeccak_out[447:416];
				8'h13:	oReadData <= wKeccak_out[415:384];
				8'h14:	oReadData <= wKeccak_out[383:352];
				8'h15:	oReadData <= wKeccak_out[351:320];
				8'h16:	oReadData <= wKeccak_out[319:288];
				8'h17:	oReadData <= wKeccak_out[287:256];
				8'h18:	oReadData <= wKeccak_out[255:224];
				8'h19:	oReadData <= wKeccak_out[223:192];
				8'h1a:	oReadData <= wKeccak_out[191:160];
				8'h1b:	oReadData <= wKeccak_out[159:128];
				8'h1c:	oReadData <= wKeccak_out[127:96];
				8'h1d:	oReadData <= wKeccak_out[95:64];
				8'h1e:	oReadData <= wKeccak_out[63:32];
				8'h1f:	oReadData <= wKeccak_out[31:0];
				default:
					begin
					end
			endcase
		end

	end


	else
	begin
		rReset_internal 	<= iReset; 
		rKeccak_in_ready	<= 1'b0;
		rKeccak_is_last 	<= 1'b0;
	end
end


always @(posedge iClk or posedge iReset)
begin
	if (iReset) 
		rAllow_in_ready <= 1'b1; 	// Always allow?


	else if(iChipSelect)
	begin
	 	if(iWrite)
	 	begin
	 		if(iAddress == 8'h01 || iAddress == 8'h03)
				rAllow_in_ready <= 1'b0;

			else
				rAllow_in_ready <= 1'b1;
	 	end


	 	else if(iRead) 
		begin
			rAllow_in_ready <= 1'b1;
		end
	end // EOF iChipSelect

	else 
	begin
		rAllow_in_ready <= 1'b1;
	end


end


endmodule

// --- KẾT THÚC FILE: keccak_wrapper.v ---

// --- BẮT ĐẦU FILE: ClockSinkDomain_6.sv ---
// Generated by CIRCT firtool-1.75.0

// Include register initializers in init blocks unless synthesis is set
`ifndef RANDOMIZE
  `ifdef RANDOMIZE_REG_INIT
    `define RANDOMIZE
  `endif // RANDOMIZE_REG_INIT
`endif // not def RANDOMIZE
`ifndef SYNTHESIS
  `ifndef ENABLE_INITIAL_REG_
    `define ENABLE_INITIAL_REG_
  `endif // not def ENABLE_INITIAL_REG_
`endif // not def SYNTHESIS

// Standard header to adapt well known macros for register randomization.

// RANDOM may be set to an expression that produces a 32-bit random unsigned value.
`ifndef RANDOM
  `define RANDOM $random
`endif // not def RANDOM

// Users can define INIT_RANDOM as general code that gets injected into the
// initializer block for modules with registers.
`ifndef INIT_RANDOM
  `define INIT_RANDOM
`endif // not def INIT_RANDOM

// If using random initialization, you can also define RANDOMIZE_DELAY to
// customize the delay used, otherwise 0.002 is used.
`ifndef RANDOMIZE_DELAY
  `define RANDOMIZE_DELAY 0.002
`endif // not def RANDOMIZE_DELAY

// Define INIT_RANDOM_PROLOG_ for use in our modules below.
`ifndef INIT_RANDOM_PROLOG_
  `ifdef RANDOMIZE
    `ifdef VERILATOR
      `define INIT_RANDOM_PROLOG_ `INIT_RANDOM
    `else  // VERILATOR
      `define INIT_RANDOM_PROLOG_ `INIT_RANDOM #`RANDOMIZE_DELAY begin end
    `endif // VERILATOR
  `else  // RANDOMIZE
    `define INIT_RANDOM_PROLOG_
  `endif // RANDOMIZE
`endif // not def INIT_RANDOM_PROLOG_
module ClockSinkDomain_6(	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9]
  output        auto_in_a_ready,	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
  input         auto_in_a_valid,	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
  input  [2:0]  auto_in_a_bits_opcode,	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
  input  [1:0]  auto_in_a_bits_size,	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
  input  [8:0]  auto_in_a_bits_source,	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
  input  [28:0] auto_in_a_bits_address,	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
  input  [7:0]  auto_in_a_bits_mask,	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
  input  [63:0] auto_in_a_bits_data,	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
  input         auto_in_d_ready,	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
  output        auto_in_d_valid,	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
  output [2:0]  auto_in_d_bits_opcode,	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
  output [1:0]  auto_in_d_bits_size,	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
  output [8:0]  auto_in_d_bits_source,	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
  output [63:0] auto_in_d_bits_data,	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
  input         auto_clock_in_clock,	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
  input         auto_clock_in_reset	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
);

  wire [31:0] _impl_oReadData;	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:76:24]
  reg  [7:0]  address;	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:66:28]
  reg  [31:0] write_data;	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:67:28]
  reg         rst;	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:68:32]
  reg         cs;	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:69:32]
  reg         we;	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:70:32]
  wire        in_bits_read = auto_in_a_bits_opcode == 3'h4;	// @[generators/rocket-chip/src/main/scala/tilelink/RegisterRouter.scala:74:36]
  wire        _out_T_3 = auto_in_a_bits_address[11:4] == 8'h0;	// @[generators/rocket-chip/src/main/scala/tilelink/Edges.scala:192:34, generators/rocket-chip/src/main/scala/tilelink/RegisterRouter.scala:75:19, :87:24]
  wire        _out_wofireMux_T_2 = auto_in_a_valid & auto_in_d_ready & ~in_bits_read;	// @[generators/rocket-chip/src/main/scala/tilelink/RegisterRouter.scala:74:36, :87:24]
  wire        out_woready_3 = _out_wofireMux_T_2 & ~(auto_in_a_bits_address[3]) & _out_T_3;	// @[generators/rocket-chip/src/main/scala/tilelink/RegisterRouter.scala:87:24]
  always @(posedge auto_clock_in_clock) begin	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
    if (out_woready_3 & auto_in_a_bits_mask[4])	// @[generators/rocket-chip/src/main/scala/tilelink/RegisterRouter.scala:87:24]
      address <= auto_in_a_bits_data[39:32];	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:66:28, generators/rocket-chip/src/main/scala/tilelink/RegisterRouter.scala:87:24]
    if (_out_wofireMux_T_2 & auto_in_a_bits_address[3] & _out_T_3 & (&{{8{auto_in_a_bits_mask[3]}}, {8{auto_in_a_bits_mask[2]}}, {8{auto_in_a_bits_mask[1]}}, {8{auto_in_a_bits_mask[0]}}}))	// @[generators/rocket-chip/src/main/scala/tilelink/RegisterRouter.scala:87:24]
      write_data <= auto_in_a_bits_data[31:0];	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:67:28, generators/rocket-chip/src/main/scala/tilelink/RegisterRouter.scala:87:24]
    if (auto_clock_in_reset) begin	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
      rst <= 1'h0;	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9, :68:32]
      cs <= 1'h0;	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9, :69:32]
      we <= 1'h0;	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9, :70:32]
    end
    else begin	// @[generators/diplomacy/diplomacy/src/diplomacy/lazymodule/LazyModuleImp.scala:107:25]
      if (out_woready_3 & auto_in_a_bits_mask[0])	// @[generators/rocket-chip/src/main/scala/tilelink/RegisterRouter.scala:87:24]
        rst <= auto_in_a_bits_data[2];	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:68:32, generators/rocket-chip/src/main/scala/tilelink/RegisterRouter.scala:87:24]
      if (out_woready_3 & auto_in_a_bits_mask[0])	// @[generators/rocket-chip/src/main/scala/tilelink/RegisterRouter.scala:87:24]
        cs <= auto_in_a_bits_data[0];	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:69:32, generators/rocket-chip/src/main/scala/tilelink/RegisterRouter.scala:87:24]
      if (out_woready_3 & auto_in_a_bits_mask[0])	// @[generators/rocket-chip/src/main/scala/tilelink/RegisterRouter.scala:87:24]
        we <= auto_in_a_bits_data[1];	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:70:32, generators/rocket-chip/src/main/scala/tilelink/RegisterRouter.scala:87:24]
    end
  end // always @(posedge)
  `ifdef ENABLE_INITIAL_REG_	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9]
    `ifdef FIRRTL_BEFORE_INITIAL	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9]
      `FIRRTL_BEFORE_INITIAL	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9]
    `endif // FIRRTL_BEFORE_INITIAL
    logic [31:0] _RANDOM[0:1];	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9]
    initial begin	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9]
      `ifdef INIT_RANDOM_PROLOG_	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9]
        `INIT_RANDOM_PROLOG_	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9]
      `endif // INIT_RANDOM_PROLOG_
      `ifdef RANDOMIZE_REG_INIT	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9]
        for (logic [1:0] i = 2'h0; i < 2'h2; i += 2'h1) begin
          _RANDOM[i[0]] = `RANDOM;	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9]
        end	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9]
        address = _RANDOM[1'h0][7:0];	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9, :66:28]
        write_data = {_RANDOM[1'h0][31:8], _RANDOM[1'h1][7:0]};	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9, :66:28, :67:28]
        rst = _RANDOM[1'h1][8];	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9, :67:28, :68:32]
        cs = _RANDOM[1'h1][9];	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9, :67:28, :69:32]
        we = _RANDOM[1'h1][10];	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9, :67:28, :70:32]
      `endif // RANDOMIZE_REG_INIT
    end // initial
    `ifdef FIRRTL_AFTER_INITIAL	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9]
      `FIRRTL_AFTER_INITIAL	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9]
    `endif // FIRRTL_AFTER_INITIAL
  `endif // ENABLE_INITIAL_REG_
  keccak_wrapper impl (	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:76:24]
    .iClk        (auto_clock_in_clock),
    .iReset      (auto_clock_in_reset | rst),	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:68:32, :81:43]
    .iChipSelect (cs),	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:69:32]
    .iWrite      (we),	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:70:32]
    .iRead       (~we),	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:70:32, :84:30]
    .iAddress    (address),	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:66:28]
    .iWriteData  (write_data),	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:67:28]
    .oReadData   (_impl_oReadData)
  );	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:76:24]
  assign auto_in_a_ready = auto_in_d_ready;	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9]
  assign auto_in_d_valid = auto_in_a_valid;	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9]
  assign auto_in_d_bits_opcode = {2'h0, in_bits_read};	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9, generators/rocket-chip/src/main/scala/tilelink/RegisterRouter.scala:74:36, :105:19]
  assign auto_in_d_bits_size = auto_in_a_bits_size;	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9]
  assign auto_in_d_bits_source = auto_in_a_bits_source;	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9]
  assign auto_in_d_bits_data = _out_T_3 ? (auto_in_a_bits_address[3] ? {_impl_oReadData, write_data} : {24'h0, address, 29'h0, rst, we, cs}) : 64'h0;	// @[generators/chipyard/src/main/scala/cipher/sha3.scala:63:9, :66:28, :67:28, :68:32, :69:32, :70:32, :76:24, generators/rocket-chip/src/main/scala/tilelink/RegisterRouter.scala:87:24, generators/rocket-chip/src/main/scala/util/MuxLiteral.scala:49:{10,48}]
endmodule


// --- KẾT THÚC FILE: ClockSinkDomain_6.sv ---

