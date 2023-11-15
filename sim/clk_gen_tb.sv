`timescale  100ns/100ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Ryan Bride
// Creation Date: 08/09/2023
// Module Name: Test Bench
// Description: 
//      Test Bench for testing the i2c modules. Pretty slapdash, most testing 
//      Will be done via flashing and running on the board. 
//////////////////////////////////////////////////////////////////////////////////

module tb;
    parameter PERIOD = 0.064; //6.4ns or 6400ps
    logic clk;  
    logic scl_t;  
  	logic enable; 
    logic SCL_PIN;
    
    //Clock Gen Instance
    clk_gen_std_100k uut(
            .CLK(clk),
      		.en(enable),
            .scl_t(scl_t)
    );
    
    assign SCL_PIN = scl_t ? 1'bZ : 1'b0;
    
    //oscillate the clock at 156.25MHz
    always #PERIOD clk = ~clk;
    
    initial begin 
        $dumpfile("clk_gen_first_test.vcd");
        $dumpvars;
    end
    
    initial begin
        clk = 0;
      	enable = 1;      
      	scl_t = 0;
      
        #5;
        enable = 0;
        
        #5;
        enable = 1;
        
        #500;
        #500;
        enable = 0;
        
        #20;
        enable = 1;
    end
    
    
endmodule

`resetall