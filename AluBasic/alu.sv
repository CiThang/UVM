// Code your design here
/*
===============================================================================================
||                                   TOP MODULE                                              ||
===============================================================================================
*/
module alu(
    input [3:0] a,
    input [3:0] b,
    input [1:0] sel,
    output[3:0] result,
    output carry_out,
    output zero
);
    wire [3:0] add_r;
    wire [3:0] sub_r;
    wire [3:0] and_r;
    wire [3:0] or_r;
    wire carry_add;
    wire carry_sub;


    add dut_add(
        .a(a),
        .b(b),
        .c_in(1'b0),
        .s(add_r),
        .c_out(carry_add)
    );

    sub dut_sub(
        .a(a),
        .b(b),
        .c_in(1'b0),
        .s(sub_r),
        .c_out(carry_sub)
    );

    mux4_1 mux(
        .sel(sel),
        .d0(carry_add),
        .d1(carry_sub),
        .d2(1'b0),
        .d3(1'b0),
        .y(carry_out)
    );

   
    and_gate dut_and(
        .a(a),
        .b(b),
        .s(and_r)
    );

    or_gate dut_or(
        .a(a),
        .b(b),
        .s(or_r)
    );

    mux4_4 dut_mux(
        .sel(sel),
        .add_r(add_r),
        .sub_r(sub_r),
        .and_r(and_r),
        .or_r(or_r),
        .result(result),
        .zero(zero)
    );



endmodule


/*
===============================================================================================
||                                   MUX4_4                                                  ||
===============================================================================================
*/
module mux4_4(
    input wire [1:0] sel,
    input wire [3:0] add_r,
    input wire [3:0] sub_r,
    input wire [3:0] and_r,
    input wire [3:0] or_r,
    output [3:0] result,
    output zero
);

    genvar i;
    generate 
        for(i=0; i<4; i=i+1) begin:mux4_4
            mux4_1 mux(
                .sel(sel),
                .d0(add_r[i]),
                .d1(sub_r[i]),
                .d2(and_r[i]),
                .d3(or_r[i]),
                .y(result[i])
            );
        end
    endgenerate

    assign zero = ~(result[0] | result[1] | result[2] | result[3]);
    
endmodule

module mux4_1(
    input  wire [1:0] sel,
    input  wire d0, d1, d2, d3,
    output wire y
);

    wire [3:0] temp_y;
    wire sel_val_3, sel_val_2, sel_val_1, sel_val_0;
    wire y2, y1;

    // Chọn d3: khi sel == 11 → sel_val_3 = sel[1] & sel[0]
    assign sel_val_3 = sel[1] & sel[0];
    assign temp_y[3] = d3 & sel_val_3;

    // Chọn giữa temp_y[3] và d2 (khi sel == 10)
    assign sel_val_2 = sel[1] & ~sel[0];
    mux2_1 mux_d2 (
        .a(temp_y[3]),
        .b(d2),
        .sel(sel_val_2),
        .y(temp_y[2])
    );

    // Chọn giữa temp_y[2] và d1 (khi sel == 01)
    assign sel_val_1 = ~sel[1] & sel[0];
    mux2_1 mux_d1 (
        .a(temp_y[2]),
        .b(d1),
        .sel(sel_val_1),
        .y(temp_y[1])
    );

    // Chọn giữa temp_y[1] và d0 (khi sel == 00)
    assign sel_val_0 = ~sel[1] & ~sel[0];
    mux2_1 mux_d0 (
        .a(temp_y[1]),
        .b(d0),
        .sel(sel_val_0),
        .y(temp_y[0])
    );

    assign y = temp_y[0];

endmodule


module mux2_1(
    input  wire a,
    input  wire b,
    input  wire sel,
    output wire y
);
    assign y = (a & ~sel) | (b & sel);
endmodule


/*
===============================================================================================
||                                       ADD                                                 ||
===============================================================================================
*/
module add (
    input [3:0] a,
    input [3:0] b,
    input c_in,
    output [3:0] s,
    output c_out
);
    wire [4:0] c;
    assign c[0] = 1'b0;

    genvar i;
    generate 
        for(i=0; i<4; i=i+1) begin: ripple_carry_adder
        full_adder fa(
            .a(a[i]),
            .b(b[i]),
            .c_in(c[i]),
            .s(s[i]),
            .c_out(c[i+1])
        );
        end
    endgenerate
    assign c_out = c[4];

endmodule
module full_adder (
    input a,b,c_in,
    output s,c_out
);

    assign s = a^b^c_in;
    assign c_out = a&b | a&c_in | b&c_in;
endmodule

/*
===============================================================================================
||                                   SUB                                                     ||
===============================================================================================
*/

module sub(  
    input [3:0] a,
    input [3:0] b,
    input c_in,
    output [3:0] s,
    output c_out
);
    wire [3:0] b_n;
    wire [3:0] b_in;
    wire c;

    genvar i;
    generate 
        for(i=0; i<4; i=i+1) begin : sub
            assign b_n[i] = b[i] ^ 1'b1;
        end
    endgenerate

    add add1(
        .a(b_n),
        .b(4'b0001),
        .c_in(1'b0),
        .s(b_in),
        .c_out(c)
    );

    add add2(
        .a(a),
        .b(b_in),
        .c_in(1'b0),
        .s(s),
        .c_out(c_out)
    );

endmodule

/*
===============================================================================================
||                                   AND_GATE                                                ||
===============================================================================================
*/

module and_gate (
    input [3:0] a,
    input [3:0] b,
    output [3:0] s
);
    genvar i;
    generate
        for(i=0; i<4; i=i+1) begin : and_gate
            assign s[i] = a[i] & b[i];
        end
    endgenerate

endmodule

/*
===============================================================================================
||                                   OR_GATE                                                 ||
===============================================================================================
*/
module or_gate (
    input [3:0] a,
    input [3:0] b,
    output [3:0] s
);
    genvar i;
    generate
        for(i=0; i<4; i=i+1) begin : or_gate
            assign s[i] = a[i] | b[i];
        end
    endgenerate

endmodule