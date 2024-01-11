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
    input sda_o,
    input scl_o,
    output scl_i,
    output scl_t,
    output sda_i,
    output sda_t
);

//State, well states 
localparam [2:0]
    IDLE                    =   3'b000,
    START_SEND              =   3'b001,
    ADDR_CLPD               =   3'b010,
    ADDR_CNTR_REG           =   3'b011,
    TURN_ON_LED4            =   3'b100,
    WRITE_TO                =   3'b101,
    READ_FROM               =   3'b110,
    WAIT_FOR_ACK            =   3'b111;

//Wires  i is the output of Circuit onto Pin, O is the read of the pin. t is the toggle
wire scl_read_filter;
wire clkgen_rst;

//Storage Regs and nets fed to regs from comb logic
reg [2:0] state_reg;        logic [2:0] state_next;
reg [2:0] state_last;       logic [2:0] state_last_next; // Kinda a funny name, used for ack
reg [2:0] w_cnt;            logic [2:0] w_cnt_next       // Counter Used and Decremented inside the state machine
reg sda_write_reg;          logic sda_write_next;
reg sda_t_reg;              logic sda_t_next; 
reg scl_t_reg;              logic scl_t_next;
reg rst_clkgen_reg;         logic rst_clkgen_next
reg scl_read_last;          logic scl_read_last_next;    //This name is so goofy I actually laughed 
//Addresses needed To send last two bits of CLPD Addr are a guess based of the doc, change if doesn't work
reg [6:0] CLPD_ADDR         = 7'b01111_10;      
reg [7:0] CLPD_CTRL_REG     = 8'b0000_0010;     // 0x02
reg [7:0] CLPD_LED4_ON      = 8'b0000_0001;     //Such a waste of mem 

assign scl_t        = scl_t_reg;
//assign scl_i        = scl_write_reg;
assign sda_t        = sda_t_reg;
assign sda_i        = sda_write_reg;
assign clkgen_rst   = rst_clkgen_reg;

//Instanciate and Connect 100KHz Module. Will flip .scl_i every 100KHz. 
clk_gen_std_100k SCL_CLK_GEN( .CLK(CLK), .rst(clkgen_rst), scl_i(scl_i))

// Glitch/Noise Filter use to filter the SCL signal read/used by the State machine should be around 50ns (ish)
ff_filter #(STAGES=2) scl_filter( .clk(CLK), ._in(scl_o), ._out(scl_read_filter) );

// After contemplating spending time constructing a reset circuit, this is an FPGA 
// so we are using Initial block, cuz I got time for that
initial begin
    state_reg       <= IDLE; 
    scl_t_reg       <= 1'b0;            scl_t_next      <= 1'b0; 
    sda_t_reg       <= 1'b0;            sda_t_next      <= 1'b0;
    //scl_write_reg   <= 1'b0;          scl_write_next  <= 1'b0;
    sda_write_reg   <= 1'b0;            sda_write_next  <= 1'b0;
    en_clk_gen_reg  <= 1'b1;            rst_clkgen_next <= 1'b1;
    w_cnt           <= 3'b111;          w_cnt_next      <= 3'b111;
    CLPD_ADDR       <= 7'b01111_10;      
    CLPD_CTRL_REG   <= 8'b0000_0010;     
    CLPD_LED4_ON    <= 8'b0000_0001;    
end

// Reset and register storage / procedural logic to coincide with the FSM logic
always_ff @(posedge clk, posedge reset) begin
    //Initial Values
    if(reset) begin
        state_reg       <= IDLE; 
        scl_t_reg       <= 1'b0;    //scl_t_next       <= 1'b0; 
        w_cnt           <= 3'b111;  //w_cnt_next       <= 3'b111;
    end else begin
        state_reg       <= state_next;
        scl_t_reg       <= scl_t_next;
        sda_t_reg       <= sda_t_next;
        //scl_write_reg   <= scl_write_next;
        sda_write_reg   <= sda_write_next;
        rst_clkgen_reg  <= clkgen_rst_next;
        w_cnt           <= w_cnt_next;
        state_last      <= state_last_next;
        scl_read_last   <= scl_read_last_next;

    end
end

//State Machine / Combinational Logic
always_comb begin
    case(state_reg)

        /** You get to Idle either after we finish everything or at the very beggining
        * The purpose of Idle is to wait for SCL and SDA to be high so we can send a start Sig
        * We are not using a multi-master bus so there should be few issues with this */        
        IDLE : begin
            //Wait til both SCL and SDA are high, then got to start
            //Not using a multi-master bus so it should always be good to go.
            if( (scl_pin_val != 1'b0) && (sda_pin_val != 1'b0) ) begin
                state_next = START_SEND;
            end
            else 
                state_next = IDLE;
        end

        /** Set _t's to '1' so that "I" is put onto the IO, Reset the clk gen so it creates a 100KHz wave, starting high
         *  where we need it. Set next state to wait for SCL low, then send address bits followed by R or W */  
        START_SEND : begin    
            sda_t_next      = 1'b1;   //Write the writes to the Pins
            scl_t_next      = 1'b1;   //Output CLK Gen onto IO pin 
            sda_write_next  = 1'b0;   //Set SDA Low
            clkgen_rst_next = 1'b0;   //Reset, reset fires on low
            state_next      = ADDR_CLPD;    
            state_last_next = START_SEND;
        end  

        /** First, turn of the reset on the CLK Gen, then wait for the first time for SCL to go low
        *   When SCL goes low set the first bit, decrement the counter. It goes high then goes low again,      
        *   Send next bit, until all bits are sent, then put in Write state after setting last state */       
        ADDR_CLPD : begin
            if(rst_clkgen_reg) begin
                rst_clkgen_next = 1'b1;         //Stop CLK Reset so count starts
                state_next      = ADDR_CLPD;    //Return to Same state
                w_cnt_next      = 3'b111;       //Propably Redundant but no reason not to be sure
            //Since we reset the clock high we know that when we hit this, SCL is High and use this in its own case
            //to avoid more SCL value change logic above
            end else if (w_cnt = 3'b111) begin
                if(scl_read_filter)
                    state_next = ADDR_CLPD;     //Wait for it to go low
                else begin
                    sda_write_next      = CLPD_ADDR[w_cnt];
                    state_next          = ADDR_CLPD;
                    w_cnt_next          = 3'b110;
                    scl_read_last_next  = 1'b0;
                end
            //Reduction or so as long as its not all 0
            end else if ( |w_cnt ) begin 
                //Should hit first, i.e. SCL is still low so check if both still 0
                if((scl_read_filter == 1'b0) && (scl_read_last == 1'b0)) 
                    state_next = ADDR_CLPD;
                //SCL changed to high and scl last low
                else if((scl_read_filter == 1'b1) && (scl_read_last == 1'b0)) begin
                    state_next = ADDR_CLPD;
                    scl_read_last_next = 1'b1;
                end
                //SCL changed back to Low, so now its time to send next bit
                else if((scl_read_filter == 1'b0) && (scl_read_last == 1'b0)) begin
                    scl_read_last_next  = 1'b0;
                    sda_write_next      = CLPD_ADDR[w_cnt];
                    w_cnt_next          = w_cnt - 1;
                    state_next          = ADDR_CLPD;
                end
            //Only case left is w_cnt is all 0
            end else begin


            end
        end

        /** 
        *   
        *   */
        ADDR_CNTR_REG : begin

        end

        /** 
        *   
        *   */
        TURN_ON_LED4 : begin

        end

        /** Simple State, just adds the Write indiciator after the end of address 
        *   This state does not affect the last state because that is literally just used for the ACK State */
        WRITE_TO : begin

        end 

        /** Simple State, justs adds the Read indicator after the end of address 
        *   This state does not affect the last state because that is literally just used for the ACK State */
        READ_FROM : begin

        end 

        /** 
        *   
        *   */
        WAIT_FOR_ACK : begin

        end 

        DEFAULT:    // You probably shouldn't be here  
    endcase

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