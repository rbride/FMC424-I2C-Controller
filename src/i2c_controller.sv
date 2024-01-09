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
    inout wire SCL_PIN,
    inout wire SDA_PIN
);

//State, well states 
localparam [2:0]
    IDLE                            =   3'b000,
    START_UP                        =   3'b001,
    IDK1                            =   3'b010,
    IDK11                           =   3'b011,
    IDK2                            =   3'b100,
    IDK122                          =   3'b101,
    IDK33                           =   3'b110,
    IDK77                           =   3'b111;

//Wires  i is the output of Circuit onto Pin, O is the read of the pin. t is the toggle
wire scl_i; scl_o; scl_t;
wire sda_i; sda_o; sda_t;
wire clkgen_rst;


//Storage Regs and nets fed to regs from comb logic
reg [2:0] state_reg; 
logic [2:0] state_next;
reg scl_write_reg; sda_write_reg; scl_t_reg; sda_t_reg; en_clk_gen_reg;
logic scl_write_reg_next; en_clkgen_next; scl_t_reg_next; sda_t_reg_next; sda_write_reg_next

assign scl_t        = scl_t_reg;
assign scl_i        = scl_write_reg;
assign sda_t        = sda_t_reg;
assign sda_i        = sda_write_reg;
assign clkgen_rst   = clkgen_rst_reg;


// After contemplating spending time constructing a reset circuit, this is an FPGA 
// so we are using Initial block, cuz I got time for that
initial begin
    state_reg       <= IDLE; 
    scl_t_reg       <= 1'b0;    scl_t_next      <= 1'b0; 
    sda_t_reg       <= 1'b0;    sda_t_next      <= 1'b0;
    scl_write_reg   <= 1'b0;    scl_write_next  <= 1'b0;
    sda_write_reg   <= 1'b0;    sda_write_next  <= 1'b0;
    en_clk_gen_reg  <= 1'b0;    en_clkgen_next  <= 1'b0;
end

// Reset and register storage / procedural logic to coincide with the FSM logic
always_ff @(posedge clk, posedge reset) begin
    //Initial Values
    if(reset) begin
        state_reg       <= IDLE; 
        scl_t_reg       <= 1'b0;    scl_t_next       <= 1'b0; 
    end 
        state_reg       <= state_next;
        scl_t_reg       <= scl_t_next;
        sda_t_reg       <= sda_t_next;
        scl_write_reg   <= scl_write_next;
        sda_write_reg   <= sda_write_next;
        clkgen_rst_reg  <= clkgen_rst_next;
    end
end

//State Machine / Combinational Logic
always_comb begin
    case(state_reg);

        /** You get to Idle either after we finish everything or at the very beggining
        * The purpose of Idle is to wait for SCL and SDA to be high so we can send a start Sig
        * We are not using a multi-master bus so there should be few issues with this */        
        IDLE: begin
            //Wait til both SCL and SDA are high, then got to start
            //Not using a multi-master bus so it should always be good to go.
            if( (scl_pin_val != 1'b0) && (sda_pin_val != 1'b0) ) begin
                state_next = START;
            end
            else 
                state_next = IDLE;
        end

        /** Set _t's to '1' so that "I" is put onto the IO, Reset the clk gen so it creates a 100KHz wave, starting high
         *  where we need it. Set next state to wait for SCL low, then send address bits followed by R or W */  
        START: begin    
            sda_t_next      = 1'b1;   //Write the writes to the Pins
            scl_t_next      = 1'b1;
            sda_write_next  = 1'b0;   //Set SDA Low
            



            //next turn on the clk generator so that it will go low after like half a period
            //then transition to the next state where I wait for a posedge / pulse of SCL
            //on that pulse start sending the ADDR
            //After sending, hold low and wait for a ack
            // then send data.. 
            ######
            #TODO#
            ######
            state_next  
        end  

        




        DEFAULT:    // You probably shouldn't be here  
    endcase

end





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