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
// IN Is the The Tri-State Buffers input to the Design
// Out is the Designs Output to the Tri-state buffer. 
module fmc_i2c_controller(
    input wire CLK,
    input wire en,
    input wire scl_in,
    output wire scl_t,
    output wire scl_out,
    input wire sda_in,
    output wire sda_t,
    output wire sda_out,
);

localparam [2:0]
    IDLE                            =   3'b000,
    START_UP                        =   3'b001,
    START                           =   3'b010,
    BUS_WAIT                        =   3'b011,
    CLPD_ADDRESS_W                  =   3'b100,
    CLPD_ADDRESS_R                  =   3'b101,
    ACC_CLPD_CTRL_REG0              =   3'b110,
    //TURN_ON_LED                     =   3'b110,
    TURN_OFF_LED                    =   3'b111;

reg [2:0] state_reg = START_UP;
reg [2:0] state_next;

//Storage Regs
reg sda_o_reg = 1'b0; sda_o_next;
reg scl_t_reg = 1'b0; scl_t_next; 

//Currently we do this because for some reason this is not the Design top
//Idk as the design nears completion I will likely make it the top because why not who cares.
assign sda_out = sda_o_reg;
assign scl_t = scl_t_reg;


//State Machine / Combinational Logic
always @* begin
    case(state_reg);
        
        IDLE: begin
            if(en) begin
                //Wait til both SCL and SDA are high, then got to start
                //Not using a multi-master bus so it should always be good to go.
                if( (sda_in != 1'b0) && (scl_in != 1'b0) ) begin
                    state_next = START;
                end
            end

            else 
                state_next = IDLE;
        end

        //So First We have to Send SDA to low, 
        START: begin
            
        end  

        




        DEFAULT:    // You probably shouldn't be here  
    endcase

end

// """Processor""" that steps the registers for the state machine and performs Actions necessary 
always @(posedge clk) begin
    state_reg <= state_next;

end



endmodule


// //CLPD Address
//  //Last two Bits are guesses based on assumptions made of crappy docs change if does not work
// localparam[7:0] CLPD_ADDR = 7'b01111_10; 

// //I2C addresses of Slave modules of FMC484
// localparam[6:0]
// SI5338B_ADR   = 7'b1110000,
//  //Wether you are talking to Module A or B is determ by selection bit of CLPD
// QSFP_MOD      = 7'b1010000;    