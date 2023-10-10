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

//Generate SCL Clock Signal to be 400Khz with Attributes defined in Readme
clk_gen scl_400khz(
            .CLK(CLK),
            .scl_t(scl_t)
);

// Glitch/Noise Filter use to filter the SCL signal read/used by the State machine
ff_filter #(STAGES=7) scl_filter( .clk(CLK), ._in(SCL_PIN), )


//Generate Clock Based ON scl_T signal. 
assign SCL_PIN = scl_t ? 1'bZ : 1'b0;




// //State Machine    
// always *@ begin

// end

// //
// always @(posedge CLK)begin

// end

endmodule

//Create I/O Buffer For SCL Pin
// IOBUF scl_buf(
//     .O(scl_out),
//     .I(scl_in),
//     .IO(SCL_PIN),
//     .T(scl_t)
// );

//Create I/O Buffer for SDA Pin
//IOBUF sda_buf(
//    .O(sda_out),
//    .I(sda_in),
//    .IO(SDA_PIN),
//    .T(sda_t)
//);

// //CLPD Address
//  //Last two Bits are guesses based on assumptions made of crappy docs change if does not work
// localparam[7:0] CLPD_ADDR = 7'b01111_10; 

// localparam [2:0]
//     START_UP                        =   3'b000,
//     IDLE                            =   3'b001,
//     START                           =   3'b010,
//     CLPD_ADDRESS_W                  =   3'b011,
//     CLPD_ADDRESS_R                  =   3'b100,
//     ACC_CLPD_CTRL_REG0              =   3'b101,
//     TURN_ON_LED                     =   3'b110,
//     TURN_OFF_LED                    =   3'b111;



// //I2C addresses of Slave modules of FMC484
// localparam[6:0]
// SI5338B_ADR   = 7'b1110000,
//  //Wether you are talking to Module A or B is determ by selection bit of CLPD
// QSFP_MOD      = 7'b1010000;    
// IOBUF
//      T -|
//         |
//  I------|>>----+---[I/O PIN]
//                |
//  O-----<<|-----+