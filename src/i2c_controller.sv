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
    input wire reset,
    input wire sda_o,
    input wire scl_o,
    output wire scl_i,
    output wire scl_t,
    output wire sda_i,
    output wire sda_t
);

//State, well states 
localparam [3:0]
    IDLE                    =   4'b0000,
    START_SEND              =   4'b0001,
    REPEATED_START          =   4'b0010,
    
    WRITE_ADDRESS           =   4'b0011,
   
    WAIT_FOR_ACK            =   4'b1110,
    STOP                    =   4'b1111;
//Physical State States
localparam [2:0]
    IDLE                        =   3'b000,
    READY                       =   3'b001,
    PHY_START_BIT               =   3'b010,
    PHY_STATE_1                 =   3'b011,
    PHY_STATE_2                 =   3'b100,
    PHY_STATE_3                 =   3'b101;


reg [7:0] addr_mem [0:4];
addr_mem[0]     =   8'b1110_001_0;      //I2C Bus SW Addr + 0 for write
addr_mem[1]     =   8'b1000_0000;       //I2C Channel Select Register value to be written
addr_mem[2]     =   8'b01111_10_0;      //CLPD address + 0 for write
addr_mem[3]     =   8'b0000_0010;       //CLPD Control Register
addr_mem[4]     =   8'b0000_0001;       //Value to be written to the control register to Turn the light on

reg cur_addr[1:0] = 2'b0;   wire cur_addr_next;
reg cur_bit [2:0] = 3'h7;   wire cur_bit_next;
reg phy_wait_flag;          logic phy_wait_flag_next;

reg dec_cur_bit_cnt;        logic dec_cur_bit_cnt_next;   
reg dec_cur_addr_cnt;       logic dec_cur_addr_cnt_next; 
reg write_cmpl;             logic write_cmpl_next;
reg ack_success;            logic ack_success_next;

assign phy_wait_flag_next = ((phy_state_reg == PHY_WAIT_1) || (phy_state_reg == PHY_WAIT_2));


wire scl_read_filter;       wire sda_read_filter;
wire clkgen_rst;
//Storage Regs and nets fed to regs from comb logic
reg [2:0] state_reg;        logic [2:0] state_next;
reg [2:0] state_last;       logic [2:0] state_last_next;    
reg scl_t_reg;              logic scl_t_next;
reg scl_read_reg;           
reg sda_t_reg;              logic sda_t_next;
reg sda_write_reg;          logic sda_write_next;
reg sda_read_reg;
reg rst_clkgen_reg;         logic rst_clkgen_next;
reg d_written;              logic d_written_next;
reg delay_rst_reg;          logic delay_rst_next;


/* Logic and Physical State FSM Spacer */ 
reg [2:0] phy_state_reg;    logic [2:0] phy_state_next;
reg scl_read_lreg;          logic scl_read_lnext; 
reg scl_read_repeat_lreg;   logic scl_read_repeat_lnext;       //#TODO REMOVE and make PHY State Better
//Addresses needed To send last two bits of CLPD Addr are a guess based of the doc, change if doesn't work
reg [6:0] CLPD_ADDR         = 7'b01111_10;
reg [7:0] CLPD_CTRL_REG     = 8'b0000_0010;
reg [7:0] CLPD_LED4_ON      = 8'b0000_0001;
reg [6:0] I2C_BUS_SW_ADDR   = 7'b1110_001;
reg [7:0] CHAN_SEL_REG       = 8'b1000_0000;

assign scl_t        =   scl_t_reg;
assign sda_t        =   sda_t_reg;
assign sda_i        =   sda_write_reg;
assign clkgen_rst   =   rst_clkgen_reg;



//Instanciate and Connect 100KHz Module. Will flip .scl_i every 100KHz. 
clk_gen_std_100k SCL_CLK_GEN( .CLK(CLK), .rst(clkgen_rst), .scl_i(scl_i));

// Glitch/Noise Filter use to filter the SCL signal read/used by the State machine should be around 50ns (ish)
ff_filter #( .STAGES(2) ) scl_filter( .clk(CLK), ._in(scl_o), ._out(scl_read_filter) );
ff_filter #( .STAGES(2) ) sda_filter( .clk(CLK), ._in(sda_o), ._out(sda_read_filter) );

//Shift Register used to create a 400ns Delay on the line 
reg delayed_out;     //When 240 ns has passed, this will flip to 1 and we are no longer held
reg delay_in_reg;  wire delay_in_next;  wire delay_rst; 
// #TODO HOly shit this code needs to be cleaned up
assign delay_rst = delay_rst_reg; 
shift_reg #( .WIDTH(12)) delay_sda_write( CLK, delay_rst, delay_in, delayed_out ); 

// Reset and register storage / procedural logic to coincide with the FSM logic.
always_ff @(posedge CLK) begin
    //Initial Values 
    if(reset) begin
        delay_in_reg        <=  1'b0;
        cur_addr            <=  2'b0;
        cur_bit             <=  3'h7;
        state_reg           <=  IDLE;    
        state_last          <=  IDLE;
        scl_t_reg           <=  1'b0;
        scl_read_reg        <=  scl_read_filter;    //Doesn't really matter what it takes on upon reset
        sda_t_reg           <=  1'b0;
        sda_write_reg       <=  1'b0;
        sda_read_reg        <=  sda_read_filter;
        rst_clkgen_reg      <=  1'b1;               //Active Low
        dec_cur_bit_cnt     <=  1'b0;
        dec_cur_addr_cnt    <=  1'b0;
        d_written           <=  1'b1;              //Strangly I think it makes more logical sense for this to start on
        write_cmpl          <=  1'b0;
        /* Logic and Physical State FSM Spacer */ 
        phy_state_reg       <=  IDLE;
        scl_read_lreg       <=  scl_read_filter;    //Doesn't really matter what it takes on upon reset
    end 
    else begin
        delay_in_reg        <=  delay_in_next;
        cur_addr            <=  cur_addr_next;
        cur_bit             <=  cur_bit_next;
        state_reg           <=  state_next;
        state_last          <=  state_last_next;
        scl_t_reg           <=  scl_t_next;
        scl_read_reg        <=  scl_read_filter;
        sda_t_reg           <=  sda_t_next;
        sda_write_reg       <=  sda_write_next;
        sda_read_reg        <=  sda_read_filter;
        rst_clkgen_reg      <=  rst_clkgen_next;
        dec_cur_bit_cnt     <=  dec_cur_bit_cnt_next;
        dec_cur_addr_cnt    <=  dec_cur_addr_cnt_next;
        d_written           <=  d_written_next;
        write_cmpl          <=  write_cmpl_next;
        ack_success         <=  ack_success_next;
        /* Logic and Physical State FSM Spacer */ 
        phy_state_reg       <=  phy_state_next;
        phy_wait_flag       <=  phy_wait_flag_next;
        scl_read_lreg       <=  scl_read_lnext;
    end
end

//State Machine / Combinational Logic
always_comb begin
    //Default values wires take on if not changed in FSM. Done here instead of Assign Statements for readability
    cur_addr_next           =   cur_addr;
    cur_bit_next            =   cur_bit;
    state_next              =   state_reg;
    state_last_next         =   state_last;
    scl_t_next              =   scl_t_reg;
    sda_t_next              =   sda_t_reg;
    sda_write_next          =   sda_write_reg;
    rst_clkgen_next         =   rst_clkgen_reg;
    dec_cur_bit_cnt_next    =   dec_cur_bit_cnt;
    dec_cur_addr_cnt_next   =   dec_cur_addr_cnt;
    d_written_next          =   d_written;
    write_cmpl_next         =   write_cmpl;
    ack_success_next        =   ack_success;
    scl_read_lnext          =   scl_read_lreg;
    //#TODO REMOVE and make PHY State Better
    scl_read_repeat_lnext   = scl_read_repeat_lreg;
    
    case(state_reg)
        /** You get to Idle either after we finish everything or at the very beggining
        * The purpose of Idle is to wait for SCL and SDA to be high so we can send a start Signal
        `* We are not using a multi-master bus so it should be like when the lines stabalize after startup 
        * When I flip the dumb switch on the board yeet */      
        IDLE : begin
            if(phy_state_reg == READY && reset == 0) begin
                state_next          =   START_SEND; 
            end
            //Otherwise make sure everything is returned to default
            else begin 
                cur_bit_next            =   3'h7;
                cur_addr_next           =   2'b00;

                state_next              =   IDLE;
                state_last_next         =   IDLE;
                scl_t_next              =   1'b0;
                sda_t_next              =   1'b0;
                rst_clkgen_next         =   1'b1;
                dec_cur_bit_cnt_next    =   1'b0;
                dec_cur_addr_cnt_next   =   1'b0;

                ack_success_next        =   1'b0;
            end
        end

        /* Set _t's to '1' so that 'Write' is put onto the IO, Reset Clk Gen, & set SDA low */  
        START_SEND : begin    
            state_next          =   WRITE_CLPD_ADDR;
            state_last_next     =   START_SEND;
            scl_t_next          =   1'b1;           //Output CLK Gen onto IO pin 
            sda_t_next          =   1'b1;           //Write the writes to the Pins
            sda_write_next      =   1'b0;           //Set SDA Low

            rst_clkgen_next     =   1'b0;           //Reset, reset fires on low
            write_cmpl_next     =   1'b0;

            ack_success_next    =   1'b0;
        end  


         // /** ACK Not Received So start again from WRITE CLPD, or from I2c, or I2c Select successful 
        // *   so repeat start send so that we can begin sending CLPD address
        // *   We do the same thing as A Stop condition except we want to go from high to low on sda     */  
        // REPEATED_START : begin
        //     //Wait for SCL To go low
        //     //Shit middle thing starts at 0. so 
        //     if ( !scl_read_repeat_lreg && scl_read_reg) begin
        //         state_next          =   REPEATED_START;
        //     end
        //     //SCL goes low, bring SDA high so I can bring it down again
        //     else if (!scl_read_repeat_lreg && !scl_read_reg) begin
        //         state_next          =   REPEATED_START;
        //         sda_write_next      =   1'b1;
        //         scl_read_repeat_lnext   =   1'b1;   //#TODO REMOVE and make PHY State Better
        //     end 
        //     //SCl Went back to high, now its time to set SDA to 0 to indicate start bit sent
        //     else if (scl_read_repeat_lreg && scl_read_reg) begin
        //         if(state_last == SET_I2CSW_FMC || state_last == SET_I2CSW_FMC) begin
        //             state_next      =   WRITE_I2C_SW;
        //         end
        //         else begin
        //             state_next          =   WRITE_CLPD_ADDR;
        //         end
        //         //potentially we can send a start bit here. Or not
        //         sda_write_next      =   1'b0;   //Indicate we start back up yeet
        //         scl_read_repeat_lnext   =   1'b0; //#TODO REMOVE and make PHY State Better  Just make it 0
        //     end
        // end
        REPEATED_START : begin

        end


        //THE NEW WRITE!!
        WRITE_ADDRESS   : begin
            //First time we enter turn of the CLK Reset
            if(!rst_clkgen_reg) begin
                state_next          = WRITE_ADDRESS;
                rst_clkgen_next     = 1'b1;
            end
            
            case(phy_state_reg) 
                PHY_START_BIT :     state_next  =   WRITE_ADDRESS;  //Still in startup
                
                //The Line is ready, wait for delay and set a SDA Bit.
                PHY_STATE_1 : begin 
                    if(!delayed_out) begin
                        state_next  =   WRITE_ADDRESS;
                        //Decrement Counter once in the Delay Period
                        if(dec_cur_bit_cnt) begin
                            dec_cur_bit_cnt_next    =   0;
                            cur_bit_next            =   cur_bit-1'b1;
                            //Done here and below, redundant but don't care, rather do it twice then not when I am suppose to
                            write_cmpl_next         =   1'b0;
                            ack_success_next        =   1'b0;
                        end
                    end
                    else begin
                        if ( |cur_bit ) begin
                            sda_write_next          =   addr_mem[cur_addr][cur_bit];
                            state_next              =   WRITE_ADDRESS;
                            //Done here and above, redundant but don't care, rather do it twice then not when I am suppose to
                            write_cmpl_next         =   1'b0;      
                            ack_success_next        =   1'b0;

                        end 
                        //We are on the Last Bit of the Send, so we need to send it to ACK
                        else begin
                            sda_write_next          =   addr_mem[cur_addr][cur_bit];
                            state_next              =   WAIT_FOR_ACK;
                            write_cmpl_next         =   1'b1;
                            dec_cur_addr_cnt_next   =   1'b1;
                        end
                    end 
                end
                PHY_STATE_2 : begin
                    //Indicate we need to decrement the counter, We will be here for a bit so its good to go
                    dec_cur_bit_cnt_next     =   1'b1;
                    state_next               =   WRITE_ADDRESS;
                end
            endcase 
        end
     
        // Fuck it we ball
        WAIT_FOR_ACK : begin
            //When we enter this state Physical State is still in PHY_STATE_1. 
            //In meantime I can decrement the ADDR but think about before doing
            case(phy_state_reg) 
                PHY_STATE_1 : begin
                    state_next = WAIT_FOR_ACK;
                    //Since we are doing nothing else here decrement the Cur address because why not
                    if(dec_cur_addr_cnt_next) begin
                        cur_addr_next           =   cur_addr - 1;
                        dec_cur_addr_cnt_next   =   1'b0;
                    end    
                end    

                PHY_STATE_2 :    state_next = WAIT_FOR_ACK;
                
                //Now we are in the low after a complete Addr send. Release SDA and wait for it to go high again
                PHY_STATE_3 : begin
                    sda_t_next          =   1'b0;   //Release SDA
                    write_cmpl_next     =   1'b0;   //We have successfully entered PHY3 so we can set this back to 0
                end

                PHY_STATE_4 : begin
                    //Wait the delay period so we are clearly inside of SCL before checking 
                    if(!delayed_out) 
                        state_next      =   WAIT_FOR_ACK; 
                    //Now we check to see the SDA has been held low by the Slave/Reciever
                    else begin
                        cur_bit_next    =   3'h7;       //Reset the Count regardless of where we go next
                        //If successful ACK will be low
                        if(!sda_read_reg) begin
                            
                            sda_t_next          =   1'b1;       //Re-assert control over SDA
                            ack_success_next    =   1'b0;
                            state_next          =   

                        end

                    end
                    
  


                end
                    //ACK failed, its so jover
                    else begin
                        sda_t_next      =   1'b1;           //Re-assert control over SDA
                        state_next      =   REPEATED_START; 
                        ack_success_next     
                        if(cur_addr < 3) begin
                            cur_addr_next   = Wroit
                        end
                    end

                end
            endcase

        end


        /* Stop Condition. We successfully send data, send the next thing or just let the BUS idle */
        STOP : begin
            state_next  =   STOP;
            // #TODO Turn on some LED on the board to indicate we got here.
        end

        default : begin 
            //NOP does nothing
        end      
    endcase
end

/* State Machine used to flag current physical state of the system/bus */
always_comb begin
    //Default values wires take on if not changed in FSM. 
    phy_state_next      =   phy_state_reg;
    delay_in_next       =   delay_in_reg;

    case(phy_state_reg) 
        /** Physical State is in IDLE when RESET is Triggered, I.E we don't want to do anything Yet */
        IDLE : begin
            if(reset == 1) 
                phy_state_next      =   IDLE;
            //When out of Reset we can go on to the READY
            else 
                phy_state_next      =   READY;
        end

        /** Ready to rock, indicates to the other state machine we are good to go and it can enter start
        *   Potentially in the future #TODO implement a check to ensure that the line is low, i.e. high for x cycles  */
        READY : begin
            //Wait til Filtered SDA_O goes low, while SCL is still high then go to Start State
            if( !(sda_read_reg) && scl_read_reg)
                phy_state_next      =   PHY_START_BIT;        
            else 
                phy_state_next      =   READY;
        end

        /** START BIT STATE. Wait for SCL to go low, then go wait to send */
        PHY_START_BIT : begin
            if(scl_read_reg) 
                phy_state_next      =   PHY_START_BIT;
            else 
                phy_state_next      =   PHY_STATE_1;
        end

        /**       ____          After Leaving Start Bit our system Looks like this. So we just fire the delay
        *   sda       \____     And After the Delay is ready we are good to go.    
        *         _______       
        *   scl          \_
        *   If we are here after going to another state and coming back we look like this
        *          ______       
        *   sda  _X______X      At this point we put our next Bit onto SDA   
        *            ___       
        *   scl  ___/   \_ 
        */
        PHY_STATE_1 : begin
            delay_in_next = 1'b1;    //Feed in the value so the write address can write the output when it hits 1
            //Hold this state til the SCL rises
            if(scl_read_reg) 
                phy_state_next      =   PHY_STATE_2;
            else
                phy_state_next      =   PHY_STATE_1;
        end
    
        /**     ___     _____     The Current SDA BIT is asserted on the Line
        *   sda    \___x_____     SCL has RISEN (Jesus Saves) wait til it falls again.    
        *       _____      _
        *    scl     \____/
        */
        PHY_STATE_2 : begin
            //Instead of having to reset it, if I just feed it 0's it will be 0 next time we need to use it 
            delay_in_next = 1'b0;    
            if(scl_read_reg) 
                phy_state_next      =   PHY_STATE_2; 
            //SCL dropped
            else begin
                //If we are done with the addr send it to PHY_STATE_3 
                if(write_cmpl)
                    phy_state_next      =   PHY_STATE_3;
                //Else We send it back to PHY_STATE_1 to continue the current Transaction
                else 
                    phy_state_next      =   PHY_STATE_1;   
            end
        end

        /**         ______       Line looks like this upon entrying to this block
        *   sda  __X______X_     You get to wait 3 because a transaction has been completely sent
        *             ___        and we are waiting to receive an ACK, after we get an ACK we return to PHY_1
        *    scl \___/   \_                                 
        */
        PHY_STATE_3 : begin
            if(scl_read_reg) 
                phy_state_next      =   PHY_STATE_4;
            else 
                phy_state_next      =   PHY_STATE_3;
        end

        /**         ______              In this state, we use delay in next to in
        *   sda  __X______X____????       
        *             ___     _          
        *    scl \___/   \___/                               
        */
        PHY_STATE_4 : begin
            //turn on the delay because although the SDA should already be low by the time the SCL rises
            //I'm still going to wait to an arbitray point a few 100 ns inside of SCl to check it
            delay_in_next = 1'b1;
            //Hold State til SCL drops low
            if(scl_read_reg) 
                phy_state_next      =   PHY_STATE_4;
            //When it falls again return to Phy_state_1 
            else 
                phy_state_next      =   PHY_STATE_1;

        end
       
    
        default : begin 
            // NOP 
        end
    endcase
end

endmodule