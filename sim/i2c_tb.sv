`timescale  100ns/100ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Ryan Bride
// Creation Date: 08/09/2023
// Module Name: i2c test bench
// Description: 
//      Slap Dash version of the I2C testbench didn't work, and fuctionality 
//      Debugging is getting harder, as a result this is a new more robust
//      Test bench setup to facilitate i2c module simulation
//////////////////////////////////////////////////////////////////////////////////


module tb;
    parameter PERIOD = 0.064; //6.4ns or 6400ps
    logic clk;  
    logic scl_t;  
    logic SCL_PIN;
    
    //Clock Gen Instance
    clk_gen uut(
            .CLK(clk),
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
        scl_t = 0;
        clk = 0;
        
        //Takes 390 clk cycles to generate one 400khz clk clock period, 6.4ns*400 = 2560
        #640;  // 2560 * 25 = 64000. move decimal over ->640
    end
    
    
endmodule

`resetall