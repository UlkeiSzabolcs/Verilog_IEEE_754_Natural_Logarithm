module log2n(clk, rst, n, log2n);
  input               clk, 
                      rst;
  input       [31:0]  n;
  output reg  [31:0]  log2n;
  
  
  wire sign;
  wire        [7:0]   exponent;
  wire        [22:0]  mantissa;
  wire        [31:0]  ieee_exponent;
  
  
  reg                 set;
  
  reg         [2:0]   state;
  reg         [2:0]   next_state;
  
  reg         [31:0]  y;
  reg         [7:0]   m;
  reg         [7:0]   m_before;
  reg         [3:0]   cnt;
  reg         [31:0]  log2mantissa;
  reg         [31:0]  ieee_log2n;
  
  localparam          Start                  = 3'd0;
  localparam          Verification           = 3'd1;
  localparam          InitializeCalculation  = 3'd2;
  localparam          SetValues              = 3'd3;
  localparam          Calculation            = 3'd4;
  localparam          SpecialCase            = 3'd5;
  localparam          Out                    = 3'd6;
  localparam          End                    = 3'd7;
  
  localparam          ieee_2                 = 32'b01000000000000000000000000000000;
  localparam          ieee_1                 = 32'b00111111100000000000000000000000;
  localparam          ieee_05                = 32'b00111111000000000000000000000000;
  
  assign              sign                   = n[31];
  assign              exponent               = n[30:23];
  assign              mantissa               = n[22:0];
  
  task print;
    input [31:0] a;
    begin
      $display("%1b - %8b - %23b", a[31], a[30:23], a[22:0]);
      $display("%32b\n", a);
    end
  endtask
  
  function [5:0] clz;
    input [31:0] a;
    begin
      casex(a)
        32'b1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx:     clz = 6'd0;
        32'b01xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx:     clz = 6'b1;
        32'b001xxxxxxxxxxxxxxxxxxxxxxxxxxxxx:     clz = 6'd2;
        32'b0001xxxxxxxxxxxxxxxxxxxxxxxxxxxx:     clz = 6'd3;
        32'b00001xxxxxxxxxxxxxxxxxxxxxxxxxxx:     clz = 6'd4;
        32'b000001xxxxxxxxxxxxxxxxxxxxxxxxxx:     clz = 6'd5;
        32'b0000001xxxxxxxxxxxxxxxxxxxxxxxxx:     clz = 6'd6;
        32'b00000001xxxxxxxxxxxxxxxxxxxxxxxx:     clz = 6'd7;
        32'b000000001xxxxxxxxxxxxxxxxxxxxxxx:     clz = 6'd8;
        32'b0000000001xxxxxxxxxxxxxxxxxxxxxx:     clz = 6'd9;
        32'b00000000001xxxxxxxxxxxxxxxxxxxxx:     clz = 6'd10;
        32'b000000000001xxxxxxxxxxxxxxxxxxxx:     clz = 6'd11;
        32'b0000000000001xxxxxxxxxxxxxxxxxxx:     clz = 6'd12;
        32'b00000000000001xxxxxxxxxxxxxxxxxx:     clz = 6'd13;
        32'b000000000000001xxxxxxxxxxxxxxxxx:     clz = 6'd14;
        32'b0000000000000001xxxxxxxxxxxxxxxx:     clz = 6'd15;
        32'b00000000000000001xxxxxxxxxxxxxxx:     clz = 6'd16; 
        32'b000000000000000001xxxxxxxxxxxxxx:     clz = 6'd17;
        32'b0000000000000000001xxxxxxxxxxxxx:     clz = 6'd18;
        32'b00000000000000000001xxxxxxxxxxxx:     clz = 6'd19;
        32'b000000000000000000001xxxxxxxxxxx:     clz = 6'd20;
        32'b0000000000000000000001xxxxxxxxxx:     clz = 6'd21;
        32'b00000000000000000000001xxxxxxxxx:     clz = 6'd22;
        32'b000000000000000000000001xxxxxxxx:     clz = 6'd23;
        32'b0000000000000000000000001xxxxxxx:     clz = 6'd24;
        32'b00000000000000000000000001xxxxxx:     clz = 6'd25;
        32'b000000000000000000000000001xxxxx:     clz = 6'd26;
        32'b0000000000000000000000000001xxxx:     clz = 6'd27;
        32'b00000000000000000000000000001xxx:     clz = 6'd28;
        32'b000000000000000000000000000001xx:     clz = 6'd29;
        32'b0000000000000000000000000000001x:     clz = 6'd30;
        32'b00000000000000000000000000000001:     clz = 6'd31;
        32'b00000000000000000000000000000000:     clz = 6'd32;
      endcase
    end
  endfunction
  
  function [31:0] ieee_add;
    input [31:0] a, b;
    input add; // 1 -> +;   0 -> -;
    reg [7:0] expa;
    reg [7:0] expb;
    reg [23:0] ma;
    reg [23:0] mb;
    reg sign;
    reg [7:0] expadd;
    reg [24:0] ovrflwm;
    reg [5:0] lz;
    begin
      expa = a[30:23];
      expb = b[30:23];
      ma = {1'b1, a[22:0]};
      mb = {1'b1, b[22:0]};
      ovrflwm = 25'b0;
      
      if(expa == expb && ma == mb && (add ? (a[31] == b[31]) : (a[31] ^ b[31]))) ieee_add = 32'b0;
      
      if(expa > expb) begin
        mb = mb >> (expa - expb);
        expadd = expa;
        sign = a[31];
      end
      else begin
        ma = ma >> (expb - expa);
        expadd = expb;
        sign = add ? ~b[31] : b[31];
      end
      
      
      if(add ? (a[31] == b[31]) : (a[31] ^ b[31])) begin
        if(mb < ma) mb = ~mb + 1'b1;
        else ma = ~ma + 1'b1;
      end
      
      ovrflwm = ma + mb;
      
      
      if(~ovrflwm[23]) begin
        if(ovrflwm[24] && (a[31] == b[31])) begin
          ovrflwm = ovrflwm >> 1;
          expadd = expadd + 1;
        end
        else begin
          lz = clz({ovrflwm[23:0], 8'b0});
          ovrflwm = ovrflwm << lz;
          expadd = expadd - lz;
        end
      end 
      
      ieee_add = {sign, expadd, ovrflwm[22:0]};
    end
  endfunction
  
  function [31:0] ieee_multiply;
    input [31:0] a, b;
    reg [47:0] mant;
    reg [7:0] exp;
    reg [5:0] lz;
    reg sign;
    begin
      if(~(|a[30:0]) || ~(|b[30:0])) ieee_multiply = {a[31] ^ b[31], 31'b0};
      if((&a[30:23] && ~(|a[22:0])) || (&b[30:23] && ~(|b[22:0]))) ieee_multiply = {a[31] ^ b[31], ~8'b0, 23'b0};
      
      mant = {1'b1, a[22:0]} * {1'b1, b[22:0]};
      exp = a[30:23] + b[30:23] - 8'd127;
      sign = a[31] ^ b[31];
      
      lz = clz(mant[47:16]);
      
      mant = mant << (lz + 1'b1);
      exp = exp - (lz - 1);
      
      ieee_multiply = {sign, exp, mant[47:25]};
    end
  endfunction
    
  function [1:0] ieee_compare;
  //00 -> equal;
  //01 -> b > a;
  //10 -> a > b;
    input [31:0] a, b;
    begin
      if(a[31] ^ b[31]) ieee_compare = {b[31], a[31]};
      else if(a[30:23] != b[30:23]) ieee_compare = {a[30:23] > b[30:23], b[30:23] > a[30:23]};
      else ieee_compare = {a[22:0] > b[22:0], b[22:0] > a[22:0]};
    end
  endfunction
  
  function [31:0] ieee_twos_pow;
    input [7:0] pow; //sm 8 bit => [-127, 127]
    reg [31:0] temp;
    reg [6:0] iterations;
    integer i;
    begin
      case(pow[7])
        0: begin
          temp = ieee_1;
          iterations = pow[6:0];
          for(i = 0; i < iterations; i = i + 1) temp = ieee_multiply(temp, ieee_2);
        end
        
        1: begin
          temp = ieee_1;
          iterations = (~pow[6:0] + 1'b1);
          for(i = 0; i < iterations; i = i + 1) temp = ieee_multiply(temp, ieee_05);
        end
      endcase
      
      ieee_twos_pow = temp;
    end
  endfunction
          
    
  always @(posedge clk)
  begin
    case(state)
      Start: begin
        set = 0;
        next_state = Verification;
      end
      
      Verification: begin
        if(sign || ~(|n)) begin
          ieee_log2n = 32'b01111111111111111111111111111111;
          next_state = Out;
        end
        else if(mantissa == 0) next_state = SpecialCase;
        else next_state = InitializeCalculation;
      end
      
      InitializeCalculation: begin
        y = n;
        m_before = 0;
        m = 0;
        cnt = 0;
        log2mantissa = 32'b0;
        next_state = SetValues;
      end
        
      SetValues: begin
        
        y = ieee_multiply(ieee_twos_pow(-(y[30:23] - 8'd127)), y);
        m_before = m_before + m;
        
        m = 0;
        if(m_before) log2mantissa = ieee_add(log2mantissa, ieee_twos_pow(-m_before), 0);
        //$display("cnt - %4b\nm - %8b", cnt, m_before); print(y);print(log2mantissa);
        
        if(cnt < 8) next_state = Calculation;
        else begin
          ieee_log2n = ieee_add(ieee_exponent, log2mantissa, 0);
          next_state = Out;
        end
      end
      
      Calculation: begin
        y = ieee_multiply(y, y);
        m = m + 1;
        if(ieee_compare(y, ieee_2) == 2'b10 || ieee_compare(y, ieee_2) == 2'b00) begin
          y = ieee_multiply(y, ieee_05);
          cnt = cnt + 1'b1;
          next_state = SetValues;
        end
        else begin
          next_state = Calculation;
        end
      end
      
      SpecialCase: begin
        ieee_log2n = ieee_exponent;
        next_state = Out;
      end
      
      Out: begin
        set = 1;
        next_state = End;
      end
      
      End: next_state = End;
    endcase
  end
      
  
  //state flipflop
  always @(posedge clk or posedge rst)
  begin
    if(rst) state <= Start;
    else state <= next_state;
  end
  
  
  //Output flipflop
  always @(posedge clk or posedge rst)
  begin
    if(rst) log2n <= 32'bx;
    else if(set) log2n <= ieee_log2n;
    else log2n <= 32'bx;
  end
  
  int_to_IEEE_754 expinst(.left_hand_side({8'd127 > exponent ? (-24'd1) : (24'd0), 8'd127 > exponent ? (~(8'd127 - exponent) + 1'b1) : exponent - 8'd127}), .right_hand_side(32'b0), .result(ieee_exponent));
  //int_to_IEEE_754 mantinst(.left_hand_side(mantint_part), .right_hand_side(mantfract_part), .result(ieee_mantissa));
  
endmodule

module log2n_tb;
  reg clk, rst;
  reg [31:0] n;
  wire [31:0] log2n;
  
  log2n l0 (.clk(clk), .rst(rst), .n(n), .log2n(log2n));
  
  localparam CLK_PERIOD = 100,
             RUNNING_CYCLES = 400, 
             RST_DURATION = 25,
             CALCULATION_CYCLES = 27;
  
  initial begin
    clk = 0;
    repeat(2 * RUNNING_CYCLES) #(CLK_PERIOD / 2) clk = ~clk;
  end
  initial begin
    rst = 1;
    #RST_DURATION rst = 0;
  end
  
  
  initial begin
    # RST_DURATION;
    
    n = $shortrealtobits(0.1);
    # (CALCULATION_CYCLES * 2 * CLK_PERIOD);
    $display("input:%f\noutput:%f\n", $bitstoshortreal(n), $bitstoshortreal(log2n));
    rst = 1;
    # RST_DURATION rst = 0;
    
    n = $shortrealtobits(8.0);
    # (CALCULATION_CYCLES * 2 * CLK_PERIOD);
    $display("input:%f\noutput:%f\n", $bitstoshortreal(n), $bitstoshortreal(log2n));
    rst = 1;
    # RST_DURATION rst = 0;
    
    n = $shortrealtobits(3.4);
    # (CALCULATION_CYCLES * 2 * CLK_PERIOD);
    $display("input:%f\noutput:%f\n", $bitstoshortreal(n), $bitstoshortreal(log2n));
    rst = 1;
    # RST_DURATION rst = 0;
    
    n = $shortrealtobits(472.3);
    # (CALCULATION_CYCLES * 2 * CLK_PERIOD);
    $display("input:%f\noutput:%f\n", $bitstoshortreal(n), $bitstoshortreal(log2n));
    rst = 1;
    # RST_DURATION rst = 0;
    
    n = $shortrealtobits(0.0);
    # (CALCULATION_CYCLES * 2 * CLK_PERIOD);
    $display("input:%f\noutput:%f\n", $bitstoshortreal(n), $bitstoshortreal(log2n));
    rst = 1;
    # RST_DURATION rst = 0;
    
    n = $shortrealtobits(-0.0);
    # (CALCULATION_CYCLES * 2 * CLK_PERIOD);
    $display("input:%f\noutput:%f\n", $bitstoshortreal(n), $bitstoshortreal(log2n));
    rst = 1;
    # RST_DURATION rst = 0;
    
    n = $shortrealtobits(-0.1);
    # (CALCULATION_CYCLES * 2 * CLK_PERIOD);
    $display("input:%f\noutput:%f\n", $bitstoshortreal(n), $bitstoshortreal(log2n));
    rst = 1;
    # RST_DURATION rst = 0;
  end
endmodule