module rockettile_dcache_data_arrays_0_ext(
  input  [8:0]   RW0_addr,
  input          RW0_clk,
  input  [255:0] RW0_wdata,
  output [255:0] RW0_rdata,
  input          RW0_en,
  input          RW0_wmode,
  input  [31:0]  RW0_wmask
);
  RSPB18_512X32M4_G1 mem_0_0 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR (RW0_addr),
    .WE  (RW0_wmode),
    .WEM (RW0_wmask[3:0]),
    .D   (RW0_wdata[31:0]),
    .OE  (1'b1),
    .Q   (RW0_rdata[31:0])
  );
  RSPB18_512X32M4_G1 mem_0_1 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR (RW0_addr),
    .WE  (RW0_wmode),
    .WEM (RW0_wmask[7:4]),
    .D   (RW0_wdata[63:32]),
    .OE  (1'b1),
    .Q   (RW0_rdata[63:32])
  );
  RSPB18_512X32M4_G1 mem_0_2 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR (RW0_addr),
    .WE  (RW0_wmode),
    .WEM (RW0_wmask[11:8]),
    .D   (RW0_wdata[95:64]),
    .OE  (1'b1),
    .Q   (RW0_rdata[95:64])
  );
  RSPB18_512X32M4_G1 mem_0_3 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR (RW0_addr),
    .WE  (RW0_wmode),
    .WEM (RW0_wmask[15:12]),
    .D   (RW0_wdata[127:96]),
    .OE  (1'b1),
    .Q   (RW0_rdata[127:96])
  );
  RSPB18_512X32M4_G1 mem_0_4 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR (RW0_addr),
    .WE  (RW0_wmode),
    .WEM (RW0_wmask[19:16]),
    .D   (RW0_wdata[159:128]),
    .OE  (1'b1),
    .Q   (RW0_rdata[159:128])
  );
  RSPB18_512X32M4_G1 mem_0_5 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR (RW0_addr),
    .WE  (RW0_wmode),
    .WEM (RW0_wmask[23:20]),
    .D   (RW0_wdata[191:160]),
    .OE  (1'b1),
    .Q   (RW0_rdata[191:160])
  );
  RSPB18_512X32M4_G1 mem_0_6 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR (RW0_addr),
    .WE  (RW0_wmode),
    .WEM (RW0_wmask[27:24]),
    .D   (RW0_wdata[223:192]),
    .OE  (1'b1),
    .Q   (RW0_rdata[223:192])
  );
  RSPB18_512X32M4_G1 mem_0_7 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR (RW0_addr),
    .WE  (RW0_wmode),
    .WEM (RW0_wmask[31:28]),
    .D   (RW0_wdata[255:224]),
    .OE  (1'b1),
    .Q   (RW0_rdata[255:224])
  );
endmodule

module rockettile_dcache_tag_array_ext(
  input  [5:0]  RW0_addr,
  input         RW0_clk,
  input  [87:0] RW0_wdata,
  output [87:0] RW0_rdata,
  input         RW0_en,
  input         RW0_wmode,
  input  [3:0]  RW0_wmask
);
  wire [23:0] mem_0_0_Q;
  wire [23:0] mem_0_1_Q;
  wire [23:0] mem_0_2_Q;
  wire [23:0] mem_0_3_Q;
  RSPB18_128X24M4_G1 mem_0_0 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR ({1'b0, RW0_addr}),
    .WE  (RW0_wmode & RW0_wmask[0]),
    .WEM (3'b111),
    .D   ({2'b0, RW0_wdata[21:0]}),
    .OE  (1'b1),
    .Q   (mem_0_0_Q)
  );
  assign RW0_rdata[21:0] = mem_0_0_Q[21:0];
  RSPB18_128X24M4_G1 mem_0_1 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR ({1'b0, RW0_addr}),
    .WE  (RW0_wmode & RW0_wmask[1]),
    .WEM (3'b111),
    .D   ({2'b0, RW0_wdata[43:22]}),
    .OE  (1'b1),
    .Q   (mem_0_1_Q)
  );
  assign RW0_rdata[43:22] = mem_0_1_Q[21:0];
  RSPB18_128X24M4_G1 mem_0_2 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR ({1'b0, RW0_addr}),
    .WE  (RW0_wmode & RW0_wmask[2]),
    .WEM (3'b111),
    .D   ({2'b0, RW0_wdata[65:44]}),
    .OE  (1'b1),
    .Q   (mem_0_2_Q)
  );
  assign RW0_rdata[65:44] = mem_0_2_Q[21:0];
  RSPB18_128X24M4_G1 mem_0_3 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR ({1'b0, RW0_addr}),
    .WE  (RW0_wmode & RW0_wmask[3]),
    .WEM (3'b111),
    .D   ({2'b0, RW0_wdata[87:66]}),
    .OE  (1'b1),
    .Q   (mem_0_3_Q)
  );
  assign RW0_rdata[87:66] = mem_0_3_Q[21:0];
endmodule

module rockettile_icache_tag_array_ext(
  input  [5:0]  RW0_addr,
  input         RW0_clk,
  input  [83:0] RW0_wdata,
  output [83:0] RW0_rdata,
  input         RW0_en,
  input         RW0_wmode,
  input  [3:0]  RW0_wmask
);
  wire [23:0] mem_0_0_Q;
  wire [23:0] mem_0_1_Q;
  wire [23:0] mem_0_2_Q;
  wire [23:0] mem_0_3_Q;
  RSPB18_128X24M4_G1 mem_0_0 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR ({1'b0, RW0_addr}),
    .WE  (RW0_wmode & RW0_wmask[0]),
    .WEM (3'b111),
    .D   ({3'b0, RW0_wdata[20:0]}),
    .OE  (1'b1),
    .Q   (mem_0_0_Q)
  );
  assign RW0_rdata[20:0] = mem_0_0_Q[20:0];
  RSPB18_128X24M4_G1 mem_0_1 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR ({1'b0, RW0_addr}),
    .WE  (RW0_wmode & RW0_wmask[1]),
    .WEM (3'b111),
    .D   ({3'b0, RW0_wdata[41:21]}),
    .OE  (1'b1),
    .Q   (mem_0_1_Q)
  );
  assign RW0_rdata[41:21] = mem_0_1_Q[20:0];
  RSPB18_128X24M4_G1 mem_0_2 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR ({1'b0, RW0_addr}),
    .WE  (RW0_wmode & RW0_wmask[2]),
    .WEM (3'b111),
    .D   ({3'b0, RW0_wdata[62:42]}),
    .OE  (1'b1),
    .Q   (mem_0_2_Q)
  );
  assign RW0_rdata[62:42] = mem_0_2_Q[20:0];
  RSPB18_128X24M4_G1 mem_0_3 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR ({1'b0, RW0_addr}),
    .WE  (RW0_wmode & RW0_wmask[3]),
    .WEM (3'b111),
    .D   ({3'b0, RW0_wdata[83:63]}),
    .OE  (1'b1),
    .Q   (mem_0_3_Q)
  );
  assign RW0_rdata[83:63] = mem_0_3_Q[20:0];
endmodule

module rockettile_icache_data_arrays_0_ext(
  input  [8:0]   RW0_addr,
  input          RW0_clk,
  input  [127:0] RW0_wdata,
  output [127:0] RW0_rdata,
  input          RW0_en,
  input          RW0_wmode,
  input  [3:0]   RW0_wmask
);
  RSPB18_512X32M4_G1 mem_0_0 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR (RW0_addr),
    .WE  (RW0_wmode & RW0_wmask[0]),
    .WEM (4'b1111),
    .D   (RW0_wdata[31:0]),
    .OE  (1'b1),
    .Q   (RW0_rdata[31:0])
  );
  RSPB18_512X32M4_G1 mem_0_1 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR (RW0_addr),
    .WE  (RW0_wmode & RW0_wmask[1]),
    .WEM (4'b1111),
    .D   (RW0_wdata[63:32]),
    .OE  (1'b1),
    .Q   (RW0_rdata[63:32])
  );
  RSPB18_512X32M4_G1 mem_0_2 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR (RW0_addr),
    .WE  (RW0_wmode & RW0_wmask[2]),
    .WEM (4'b1111),
    .D   (RW0_wdata[95:64]),
    .OE  (1'b1),
    .Q   (RW0_rdata[95:64])
  );
  RSPB18_512X32M4_G1 mem_0_3 (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR (RW0_addr),
    .WE  (RW0_wmode & RW0_wmask[3]),
    .WEM (4'b1111),
    .D   (RW0_wdata[127:96]),
    .OE  (1'b1),
    .Q   (RW0_rdata[127:96])
  );
endmodule

module mem_ext(
  input  [12:0] RW0_addr,
  input         RW0_clk,
  input  [63:0] RW0_wdata,
  output [63:0] RW0_rdata,
  input         RW0_en,
  input         RW0_wmode,
  input  [7:0]  RW0_wmask
);
  RSPB18_8KX32M16_G1 mem_lo (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR (RW0_addr),
    .WE  (RW0_wmode),
    .WEM (RW0_wmask[3:0]),
    .D   (RW0_wdata[31:0]),
    .OE  (1'b1),
    .Q   (RW0_rdata[31:0])
  );
  RSPB18_8KX32M16_G1 mem_hi (
    .CLK (RW0_clk),
    .ME  (RW0_en),
    .ADR (RW0_addr),
    .WE  (RW0_wmode),
    .WEM (RW0_wmask[7:4]),
    .D   (RW0_wdata[63:32]),
    .OE  (1'b1),
    .Q   (RW0_rdata[63:32])
  );
endmodule
