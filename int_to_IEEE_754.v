module int_to_IEEE_754(left_hand_side, right_hand_side, result);
  
  input       [31:0]  left_hand_side;
  input       [31:0]  right_hand_side;
  output reg  [31:0]  result;

    `define MAX_DEC_LENGTH 10
    `define REG_WIDTH 31
    `define BASE_EXP_VAL 127
    `define MANTISSA_MSB 22

    // grab sign bit 
    function set_sign;
    input [31:0] data;
    begin
        set_sign = data[31];
    end
    endfunction

    // set the exponent value 
    function [7:0] set_msb_index;
    input [31:0] data;
    reg   [31:0] result; 
    integer i;
    begin
        result = -1;
        
        if(data[31] == 0) begin 
            // find the most significant 1 bit after the sign
            for(i = `REG_WIDTH; i >= 0 && result == -1; i = i - 1) begin
                if(data[i] == 1)
                    result = i;
            end
        end

        else if(data[31] == 1) begin
            // find the most significant 1 bit after the sign
            for(i = 0; i <= `REG_WIDTH && result == -1; i = i + 1) begin
                if(data[i] == 1)
                    result = i;
            end

        end

        if(result == -1) begin 
            result = 0; 
        end 
        
        set_msb_index = result; 
    end
    endfunction

    // convert rhs argument to fractional binary value 
    function [31:0] convert_rhs; 
    input [31:0] data;
    reg   [31:0] result; 
    integer i; 
    integer max; 
    begin

        max = 0;

        // find base 10 that is larger than our rhs 
        for(i = 1; i < `MAX_DEC_LENGTH && max == 0; i = i + 1) begin
            if((10 ** i) > data)
                max = 10 ** i;
        end

        result = 32'b0;

        // use the multiple + push technique to generate a binary fractal number
        for(i = 0; i <= `REG_WIDTH; i = i + 1) begin

            // multiply the decimal num by 2 
            data = data * 2;

            // shift our binary fraction left each time
            result = result << 1;

            // if dec result was > than e.g. 100, we push a 1
            if(data >= max) begin
                data = data - max;
                result = result | 1'b1;
            end

            // else we push a 0 
            else begin
                result = result | 1'b0; 
            end

        end
        convert_rhs = result; 
    end
    endfunction


    task convert;
    // main program variables
    input [31:0] lhs; // Left had side of the decimal number.
    input [31:0] rhs; // Right hand side of the decimal number.
    output [31:0] op_rslt;
    reg [31:0] res; // Resulting IEEE 754 value

    integer rhs_decimal; 
    integer left_msb_index;
    integer right_msb_index;
    integer lhs_mask; 
    integer rhs_mask;
    integer sign; 
    integer i;
    begin
        
        rhs_decimal = rhs;

        lhs_mask = 0;
        rhs_mask = 0; 
        sign = 0;

        if(lhs[31] == 1) begin 
            lhs = ~(lhs - 1);
            sign = 1'b1;
        end

        // find most sigificant 1-bit on lhs
        left_msb_index = set_msb_index(lhs);

        // convert rhs to binary fraction
        // find most significant 1-bit on rhs  
        rhs = convert_rhs(rhs);

        right_msb_index = set_msb_index(rhs);

        if(lhs != 0) begin 

            // set mask for lhs 
            for(i = 0; i < left_msb_index; i = i + 1)
                lhs_mask[i] = 1'b1;
    
            res[22:0] = (lhs & lhs_mask) << ((`MANTISSA_MSB - left_msb_index) + 1);
            res[22:0] = res[22:0] | (rhs >> (left_msb_index + 9));

            // set the last bit to 1 to round up 
            if(right_msb_index > `MANTISSA_MSB) begin 
                for(i = right_msb_index - `MANTISSA_MSB; i >= 0; i = i - 1)
                    if(rhs[i] == 1)
                        res[0] = 1;
            end 

            if(sign == 0)
                sign = set_sign(lhs);
            res[31] = sign;

            // exponent
            res[30:23] = 127 + left_msb_index;
            op_rslt = res;
        end

    end
    endtask
    
    always @(left_hand_side or right_hand_side)
    begin
      convert(left_hand_side, right_hand_side, result);
    end
endmodule