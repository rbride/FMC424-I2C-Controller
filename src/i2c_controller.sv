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
    WR_ADDR_CLPD            =   3'b010,
    WRITE_BIT_AFTER_CLPD    =   3'b011,
    ADDR_CNTR_REG           =   3'b100,
    TURN_ON_LED4            =   3'b101,
    WAIT_FOR_WRITE          =   3'b110,
    WAIT_FOR_ACK            =   3'b111;
//Physical State States
localparam [2:0]
    BOTH_LINES_RELEASED     =   3'b000,
    PHY_WAIT_TO_WRITE       =   3'b001,
    PHY_WRITE_TO_SDA        =   3'b010,
    ACK_ACK                 =   3'b101;

wire scl_read_filter;
wire clkgen_rst;
//Storage Regs and nets fed to regs from comb logic
reg [2:0] state_reg;        logic [2:0] state_next;
reg [2:0] state_last;       logic [2:0] state_last_next;    
reg scl_t_reg;              logic scl_t_next;
reg scl_read_reg;           
reg sda_t_reg;              logic sda_t_next;
reg sda_write_reg;          logic sda_write_next;
reg rst_clkgen_reg;         logic rst_clkgen_next;
reg [3:0] wr_cnt;           logic [3:0] wr_cnt_next;        // Counter Used and Decremented inside the state machine
reg d_written;              logic d_written_next;
/* Logic and Physical State FSM Spacer */ 
reg [2:0] phy_state_reg;    logic [2:0] phy_state_next;
reg [2:0] phy_state_lreg;   logic [2:0] phy_state_lnext; 
reg scl_read_lreg;          logic scl_read_lnext; 
//Addresses needed To send last two bits of CLPD Addr are a guess based of the doc, change if doesn't work
reg [6:0] CLPD_ADDR         = 7'b01111_10;
reg [7:0] CLPD_CTRL_REG     = 8'b0000_0010;
reg [7:0] CLPD_LED4_ON      = 8'b0000_0001;

assign scl_t        =   scl_t_reg;
assign sda_t        =   sda_t_reg;
assign sda_i        =   sda_write_reg;
assign clkgen_rst   =   rst_clkgen_reg;
//Instanciate and Connect 100KHz Module. Will flip .scl_i every 100KHz. 
clk_gen_std_100k SCL_CLK_GEN( .CLK(CLK), .rst(clkgen_rst), scl_i(scl_i));

// Glitch/Noise Filter use to filter the SCL signal read/used by the State machine should be around 50ns (ish)
// Might change to 1
ff_filter #(STAGES = 2) scl_filter( .clk(CLK), ._in(scl_o), ._out(scl_read_filter) );

// After contemplating spending time constructing a reset circuit, this is an FPGA 
// so we are using Initial block, cuz I got time for that
initial begin
    state_reg       <=  IDLE;
    state_last      <=  IDLE;
    scl_t_reg       <=  1'b0;
    scl_read_reg    <=  scl_read_filter;     //Doesn't really matter what it takes on upon init
    sda_t_reg       <=  1'b0;            
    sda_write_reg   <=  1'b0;
    rst_clkgen_reg  <=  1'b1;                //Active Low
    wr_cnt          <=  4'h8;
    d_written       <=  1'b1;
    /* Logic and Physical State FSM Spacer */ 
    phy_state_reg   <=  BOTH_LINES_RELEASED;
    phy_state_lreg  <=  BOTH_LINES_RELEASED;  
    scl_read_lreg   <=  scl_read_filter;     //Doesn't really matter what it takes on upon init
    //Addresses below are static and never change so don't need to put them in reset
    CLPD_ADDR       <=  7'b01111_10;
    CLPD_CTRL_REG   <=  8'b0000_0010;
    CLPD_LED4_ON    <=  8'b0000_0001;    
end

// Reset and register storage / procedural logic to coincide with the FSM logic.
always_ff @(posedge clk, posedge reset) begin
    //Initial Values 
    if(reset) begin
        state_reg       <=  IDLE;    
        state_last      <=  IDLE;
        scl_t_reg       <=  1'b0;
        scl_read_reg    <=  scl_read_filter;    //Doesn't really matter what it takes on upon reset
        sda_t_reg       <=  1'b0;
        sda_write_reg   <=  1'b0;
        rst_clkgen_reg  <=  1'b1;               //Active Low
        wr_cnt          <=  4'h8;  
        d_written       <=   1'b1;              //Strangly I think it makes more logical sense for this to start on
        /* Logic and Physical State FSM Spacer */ 
        phy_state_reg   <=  BOTH_LINES_RELEASED;
        phy_state_lreg  <=  BOTH_LINES_RELEASED;
        scl_read_lreg   <=  scl_read_filter;    //Doesn't really matter what it takes on upon reset
    end 
    else begin
        state_reg       <=  state_next;
        state_last      <=  state_last_next;
        scl_t_reg       <=  scl_t_next;
        scl_read_reg    <=  scl_read_filter;
        sda_t_reg       <=  sda_t_next;
        sda_write_reg   <=  sda_write_next;
        rst_clkgen_reg  <=  rst_clkgen_next;
        wr_cnt          <=  wr_cnt_next;
        d_written       <=  d_written_next;
        /* Logic and Physical State FSM Spacer */ 
        phy_state_reg   <=  phy_state_next;
        phy_state_lreg  <=  phy_state_lnext;
        scl_read_lreg   <=  scl_read_lnext;
    end
end

//State Machine / Combinational Logic
always_comb begin
    //Default values wires take on if not changed in FSM. Done here instead of Assign Statements for readability
    state_next          =   state_reg;
    state_last_next     =   state_last;
    scl_t_next          =   scl_t_reg;
    sda_t_next          =   sda_t_reg;
    sda_write_next      =   sda_write_reg;
    rst_clkgen_next     =   rst_clkgen_reg;
    wr_cnt_next         =   wr_cnt;
    d_written_next      =   d_written;
    
    case(state_reg)
        /** You get to Idle either after we finish everything or at the very beggining
        * The purpose of Idle is to wait for SCL and SDA to be high so we can send a start Signal
        * We are not using a multi-master bus so it should be like when the lines stabalize after startup */        
        IDLE : begin
            if( (scl_pin_val != 1'b0) && (sda_pin_val != 1'b0) ) begin
                state_next          =   START_SEND; 
            end
            //Otherwise make sure everything is returned to default
            else begin 
                state_next          =   IDLE;
                state_last_next     =   IDLE;
                scl_t_next          =   1'b0;
                sda_t_next          =   1'b0;
                rst_clkgen_next     =   1'b1;
                wr_cnt              =   4'h8;
            end
        end

        /** Set _t's to '1' so that 'Write' is put onto the IO, Reset Clk Gen, & set SDA low */  
        START_SEND : begin    
            state_next          =   WR_ADDR_CLPD;
            state_last_next     =   START_SEND;
            scl_t_next          =   1'b1;           //Output CLK Gen onto IO pin 
            sda_t_next          =   1'b1;           //Write the writes to the Pins
            sda_write_next      =   1'b0;           //Set SDA Low
            rst_clkgen_next     =   1'b0;           //Reset, reset fires on low
        end  

        /** First, turn of the reset on the CLK Gen, then wait for the first time for SCL to go low
        *   When SCL goes low set the first bit, decrement the counter. It goes high then goes low again,      
        *   Send next bit, until all bits are sent, then put in Write state after setting last state */       
        WR_ADDR_CLPD : begin
            if (rst_clkgen_reg) begin
                state_next          =   WR_ADDR_CLPD;
                rst_clkgen_next     =   1'b1;
                wr_cnt_next         =   4'h8;
            end
            
            //Writes all the data in the address for CLPD 
            else if ( |wr_cnt ) begin
                //Wait for SCL to go low for the first time then send the first bit
                if (phy_state_reg == PHY_WAIT_TO_WRITE)
                    state_next          =   WR_ADDR_CLPD;       //Only gets hit the first time we enter
                //After goes low send first/next bit of addr
                else if (phy_state_reg == PHY_WRITE_TO_SDA) begin
                    state_next          =   WAIT_FOR_WRITE;
                    state_last_next     =   WR_ADDR_CLPD;
                    sda_write_next      =   CLPD_ADDR[(wr_cnt - 1'b1)];
                    wr_cnt_next         =   wr_cnt - 1'b1;   
                    d_written_next      =   1'b1;
                end
            end
            /* Write write bit to sda. The fact that write is '0' is dumb just wanted that to be known */
            else begin
                state_next      =   WAIT_FOR_WRITE;  
                state_last      =   WRITE_BIT_AFTER_CLPD; //Fake case used to transition easily in the wait_for_write
                d_written_next  =   1'b1; 
            end
             
        end 

        //WRITE_BIT_AFTER_CLPD : NOP         
        /* Pause waiting. then return to where we were after ready to write another bit */
        WAIT_FOR_WRITE : begin
            //This literally just exist to ensure a wait of 1 clock cycle lmao
            if (d_written_reg) begin
                d_written_next      =   1'b0;               
                state_next          =   WAIT_FOR_WRITE;
            end
            else if ( (phy_state_reg == PHY_WRITE_TO_SDA) && (phy_state_lreg == PHY_WAIT_TO_WRITE)) begin
                case(state_last)
                    WR_ADDR_CLPD            :  state_next   =   WR_ADDR_CLPD;
                    WRITE_BIT_AFTER_CLPD    :  state_next   =   WAIT_FOR_ACK;
                    ADDR_CNTR_REG           :  state_next   =   ADDR_CNTR_REG;
                    TURN_ON_LED4            :  state_next   =   TURN_ON_LED4;
                endcase
            end else begin
                state_next      =   WAIT_FOR_WRITE;
            end
        
        end

        /* Wait for the ACK then return to the previous if received, if not keep trying 
         * Ack is gotten by releasing SDA and seeing if the Receiver/Slave can hold it low */
        WAIT_FOR_ACK : begin
            
        end 

        default : begin 
            //NOP does nothing
        end
        
    endcase
end

/* State Machine used to flag current physical state of the system/bus */
always_comb begin
    //Default values wires take on if not changed in FSM. 
    phy_state_next  = BOTH_LINES_RELEASED;
    phy_state_lnext = BOTH_LINES_RELEASED;

    case(phy_state_reg) 
        /** Starting Physical State of the Bus, Both SCL & SDA 'Released' (High Z or 1) & neither _t is asserted 
        *   Holds til sda_o drops which indicates are start bit has been sent */
        BOTH_LINES_RELEASED : begin
            if (sda_o) begin
                phy_state_next      =   PHY_WAIT_TO_WRITE;
                phy_state_lnext     =   BOTH_LINES_RELEASED;
            end
            else begin 
                phy_state_next      =   BOTH_LINES_RELEASED;
            end
        end
        
        /* SDA is Set low, and clk gen has started so we are currently waiting for the SCL to go low */
        PHY_WAIT_TO_WRITE : begin
            if (phy_state_lreg == BOTH_LINES_RELEASED) begin
                if (!scl_read_reg) begin
                    phy_state_next      =   PHY_WRITE_TO_SDA;
                    phy_state_lnext     =   PHY_WAIT_TO_WRITE;
                end else 
                    phy_state_next      =   PHY_WAIT_TO_WRITE;
            end
            else if (phy_state_lreg == PHY_WRITE_TO_SDA) begin
                //Scl Rises after going low and asserting a SDA bit on the bit scl_last is 0 and now the reg is 1
                if ((!scl_read_lreg) && scl_read_reg) begin
                    scl_read_lnext      =   1'b1;
                    phy_state_next      =   PHY_WAIT_TO_WRITE;
                    phy_state_lnext     =   PHY_WAIT_TO_WRITE;
                //After rising scl falls again, we are now ready to send another bit
                end 
                else if (scl_read_lreg && (!scl_read_reg)) begin
                    phy_state_next      =   PHY_WRITE_TO_SDA;
                    phy_state_lnext     =   PHY_WAIT_TO_WRITE;
                end
            end
        end
        
        //////
        ////// NOTES I am guessing if this fails that the reason is, d_written and 
        ////// the lreg don't stand long enough for it to propagate
        PHY_WRITE_TO_SDA : begin
            //Hold Indicator to fsm that It needs to write the SDA til it tells me It wrote one
            if(phy_state_lreg == PHY_WAIT_TO_WRITE || d_written_reg) begin
                phy_state_next      =   PHY_WRITE_TO_SDA;
                phy_state_lnext     =   PHY_WRITE_TO_SDA;
            end
            //When we are sure bit is written, go back to waiting to tell the FSM to write again 
            else begin
                phy_state_next      =   PHY_WAIT_TO_WRITE;
                phy_state_lnext     =   PHY_WRITE_TO_SDA;
                scl_read_lnext      =   1'b0;               //Indicate that we know SCl hit 0 at some point
            end
        end



        /** After the address/data send we wait for the ack, the master, which is us releases the SDA line 
        *   And watches to make sure that the receiver/slave pulls it low by the 9th clock pulse, if it does not
        *   something has gone wrong and we need to go back to the start and try again. */ 
        ACK_ACK : begin

        end


    endcase
end

endmodule