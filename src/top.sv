`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Ryan Bride 
// Create Date: 08/05/2023
// Module Name: fmc_i2c_controller
// Target Devices: Ultrascale RFSOC FPGA Connected to FMC424 Board 
// Description: 
//      Master I2C Controller that Connects to and controls FMC424 add on board
// Revision 1 - Initial Design  
//////////////////////////////////////////////////////////////////////////////////
//for reference upon completion for hookup
//https://docs.xilinx.com/r/en-US/ug571-ultrascale-selectio/SelectIO-Interface-Attributes-and-Constraints
//https://support.xilinx.com/s/article/61861?language=en_US
module fmc_i2c_controller(
    input wire CLK,
    inout wire SCL_PIN,
    inout wire SDA_PIN
);

wire scl_t;
wire scl_i_flt; //Filtered Pin Read of SCL

//Generate Clock Based ON scl_T signal. 
assign SCL_PIN = scl_t ? 1'bZ : 1'b0;

localparam [2:0]
    START_UP                        =   3'b000,
    IDLE                            =   3'b001,
    START                           =   3'b010,
    CLPD_ADDRESS_W                  =   3'b011,
    CLPD_ADDRESS_R                  =   3'b100,
    ACC_CLPD_CTRL_REG0              =   3'b101,
    TURN_ON_LED                     =   3'b110,
    TURN_OFF_LED                    =   3'b111;

reg [2:0] state_reg = START_UP;
reg [2:0] state_next;










// """Processor""" that steps the registers for the state machine and performs Actions necessary 
always @(posedge clk) begin
    state_reg <= state_next;



end





//Generate Standard 100KHz clock as that is what the CLPD on the Extension Board Supports
clk_gen_std_100k SCL_CLK_GEN(   .CLK(CLK),  .scl_t(scl_t)   );






endmodule

// //CLPD Address
//  //Last two Bits are guesses based on assumptions made of crappy docs change if does not work
// localparam[7:0] CLPD_ADDR = 7'b01111_10; 

// //I2C addresses of Slave modules of FMC484
// localparam[6:0]
// SI5338B_ADR   = 7'b1110000,
//  //Wether you are talking to Module A or B is determ by selection bit of CLPD
// QSFP_MOD      = 7'b1010000;    


// Move to top level you don't instatiate inside of the module Do it at top level in vivado 
// //Create I/O Buffer for SDA Pin
// IOBUF sda_buf(  .O(sda_o),
//                 .I(sda_i), 
//                 .IO(SDA_PIN),
//                 .T(sda_t)
// );
// //Create I/O Buffer for SCL Pin
// IOBUF scl_buf(  .O(scl_o),
//                 .I(scl_i),
//                 .IO(SCL_PIN),
//                 .T(scl_t)
// );

// // Assign Tri States pins 
// // IOBUF
// //      T -|
// //         |
// //  I------|>>----+---[I/O PIN]
// //                |
// //  O-----<<|-----+
// assign SCL_PIN = scl_t ? 1'bZ : scl_i; //SCL is either high Z or output of Clk Gen
// assign SDA_PIN = sda_t ? 1'bZ : sda_i; //SDA is either high Z or Output of State Machine