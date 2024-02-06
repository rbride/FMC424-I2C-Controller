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
    output wire sda_t,
    output wire done_led,
    output wire [2:0] state_debug,
    output wire [2:0] phy_state_debug,
    output wire [2:0] cur_bit_debug,
    output wire [1:0] cur_addr_debug
);

//State, well states 
localparam [2:0]
    IDLE                    =   3'b000,
    START_UP                =   3'b001,
    START_SEND              =   3'b010,
    REPEATED_START          =   3'b011,
    WRITE_ADDRESS           =   3'b100,
    WAIT_FOR_ACK            =   3'b101,
    STOP                    =   3'b110,
    BOARD_LED               =   3'b111;
//Physical State States
localparam [2:0]
    PHY_IDLE                    =   3'b000,
    PHY_READY                   =   3'b001,
    PHY_START_BIT               =   3'b010,
    PHY_STATE_1                 =   3'b011,
    PHY_STATE_2                 =   3'b100,
    PHY_STATE_3                 =   3'b101,
    PHY_STATE_4                 =   3'b110;    


reg [4:0][7:0] addr_mem =  {
                            8'b0000_0001,   //Value to be written to the control register to Turn the light on
                            8'b0000_0010,   //CLPD Control Register
                            8'b01111_10_0,  //CLPD address + 0 for write
                            8'b1000_0000,   //I2C Channel Select Register value to be written
                            8'b1110_001_0   //I2C Bus SW Addr + 0 for write
                           };

//Stuff added by redesign re-org
(* mark_debug = "true" *) reg [1:0]cur_addr = 2'b0;   
logic [1:0] cur_addr_next;
(* mark_debug = "true" *) reg [2:0]cur_bit  = 3'h7;  
logic [2:0] cur_bit_next;
reg dec_cur_bit_cnt;        logic dec_cur_bit_cnt_next;   
reg dec_cur_addr_cnt;       logic dec_cur_addr_cnt_next;        //#TODO bro called it Dec address when the value increments 
reg write_cmpl;             logic write_cmpl_next;
reg delay_rst_reg = 1'b0;   logic delay_rst_next;              // Idk fuck it initialize here 
reg done_reg;               logic done_next;

reg done_led_on_reg;        logic done_led_on_next;           
assign done_led = done_led_on_reg;

reg bus_ready_reg;          logic bus_ready_next;

wire scl_read_filter;       wire sda_read_filter;
wire clkgen_rst;
//Storage Regs and nets fed to regs from comb logic
reg [2:0] state_reg;        logic [2:0] state_next;
reg scl_t_reg;              logic scl_t_next;
reg scl_read_reg;           
reg sda_t_reg;              logic sda_t_next;
reg sda_write_reg;          logic sda_write_next;
reg sda_read_reg;
reg rst_clkgen_reg;         logic rst_clkgen_next;


/* Logic and Physical State FSM Spacer */ 
(* mark_debug = "true" *) reg [2:0] phy_state_reg;    
logic [2:0] phy_state_next;
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


reg scl_i_reg; logic scl_i_next; wire clk_gen_scl_i;
assign scl_i = scl_i_reg;
//Instanciate and Connect 100KHz Module. Will flip .scl_i every 100KHz. 
clk_gen_std_100k SCL_CLK_GEN( .CLK(CLK), .rst(clkgen_rst), .scl_i(clk_gen_scl_i));

// Glitch/Noise Filter use to filter the SCL signal read/used by the State machine should be around 50ns (ish)
ff_filter #( .STAGES(2) ) scl_filter( .clk(CLK), ._in(scl_o), ._out(scl_read_filter) );
ff_filter #( .STAGES(2) ) sda_filter( .clk(CLK), ._in(sda_o), ._out(sda_read_filter) );

//Shift Register used to create a 400ns Delay on the line 
reg delayed_out;     //When 240 ns has passed, this will flip to 1 and we are no longer held
reg delay_in_reg;  logic delay_in_next;  wire delay_rst; 
// #TODO HOly shit this code needs to be cleaned up
assign delay_rst = delay_rst_reg; 
shift_reg #( .WIDTH(5)) delay_sda_write( CLK, delay_rst, delay_in_reg, delayed_out ); 

//Debug stuff
assign state_debug      = state_reg;
assign phy_state_debug  = phy_state_reg;
assign cur_bit_debug    = cur_bit;
assign cur_addr_debug   = cur_addr; 

// Reset and register storage / procedural logic to coincide with the FSM logic.
always_ff @(posedge CLK) begin
    //Initial Values 
    if(reset) begin
        /* Ensure Both States are IDLE */ 
        state_reg           <=  IDLE;    
        phy_state_reg       <=  PHY_IDLE;

        scl_i_reg           <=  1'b0;

        delay_in_reg        <=  1'b0;
        delay_rst_reg       <=  1'b1;       
        cur_addr            <=  2'b0;
        cur_bit             <=  3'h7;
        done_reg            <=  1'b0;
        scl_t_reg           <=  1'b0;
        sda_t_reg           <=  1'b0;
        sda_write_reg       <=  1'b0;
        rst_clkgen_reg      <=  1'b1;               //Active Low
        dec_cur_bit_cnt     <=  1'b0;
        dec_cur_addr_cnt    <=  1'b0;
        write_cmpl          <=  1'b0;
        done_led_on_reg     <=  1'b0;
        
        bus_ready_reg       <=  1'b0;
    end 
    else begin
        scl_i_reg           <=  scl_i_next;

        bus_ready_reg       <=  bus_ready_next;

        delay_in_reg        <=  delay_in_next;
        delay_rst_reg       <=  delay_rst_next;
        cur_addr            <=  cur_addr_next;
        cur_bit             <=  cur_bit_next;
        done_reg            <=  done_next;
        state_reg           <=  state_next;
        scl_t_reg           <=  scl_t_next;
        scl_read_reg        <=  scl_read_filter;
        sda_t_reg           <=  sda_t_next;
        sda_write_reg       <=  sda_write_next;
        sda_read_reg        <=  sda_read_filter;
        rst_clkgen_reg      <=  rst_clkgen_next;
        dec_cur_bit_cnt     <=  dec_cur_bit_cnt_next;
        dec_cur_addr_cnt    <=  dec_cur_addr_cnt_next;
        write_cmpl          <=  write_cmpl_next;
        done_led_on_reg     <=  done_led_on_next;
        /* Logic and Physical State FSM Spacer */ 
        phy_state_reg       <=  phy_state_next;
    end
end

//State Machine / Combinational Logic
always_comb begin
    //Default values wires take on if not changed in FSM. Done here instead of Assign Statements for readability
    cur_addr_next           =   cur_addr;
    cur_bit_next            =   cur_bit;
    state_next              =   state_reg;
    scl_t_next              =   scl_t_reg;
    sda_t_next              =   sda_t_reg;
    sda_write_next          =   sda_write_reg;
    rst_clkgen_next         =   rst_clkgen_reg;
    dec_cur_bit_cnt_next    =   dec_cur_bit_cnt;
    dec_cur_addr_cnt_next   =   dec_cur_addr_cnt;
    write_cmpl_next         =   write_cmpl;
    done_next               =   done_reg;

    scl_i_next              =   scl_i_reg;

    delay_rst_next          =   delay_rst_reg;
    done_led_on_next        =   done_led_on_reg;

    bus_ready_next          =   bus_ready_reg;

    case(state_reg)

        IDLE : begin
            if(phy_state_reg == PHY_READY) begin
                state_next          =   START_UP; 
                //Assert Control over SDA and SCL, SET SDA to one so that it can be brough down
                sda_t_next          =   1'b1;
                scl_t_next          =   1'b1;
                sda_write_next      =   1'b1;
                
                rst_clkgen_next     =   1'b0;
        
            end
            //Otherwise make sure everything is returned to default
            else begin 
                state_next              =   IDLE;
                
                bus_ready_next          =   1'b0;
                cur_bit_next            =   3'h7;
                cur_addr_next           =   2'b00;
                delay_rst_next          =   1'b1;

                scl_t_next              =   1'b0;
                sda_t_next              =   1'b0;
                rst_clkgen_next         =   1'b1;
                dec_cur_bit_cnt_next    =   1'b0;
                dec_cur_addr_cnt_next   =   1'b0;

                scl_i_next              =   1'b0;
            end
        end

        /* Point of this State is to get  */  
        START_UP : begin
            state_next      =   START_UP;
            //First time we enter turn of the CLK Reset
            if(!rst_clkgen_reg) begin
                state_next          =   START_UP;
                rst_clkgen_next     =   1'b1;
            end
            else begin
                //Now we make it so that the output of the clock gen is the output for SCL
                scl_i_next          =   clk_gen_scl_i;
                //When the filter tells us that both are high, we can go and send the start bit
                if(sda_read_reg && scl_read_reg) begin
                    state_next      =   START_SEND;
                    bus_ready_next  =   1'b1;  
                end
            end



        end

        /* Set _t's to '1' so that 'Write' is put onto the IO, Reset Clk Gen, & set SDA low */  
        START_SEND : begin    
            state_next          =   WRITE_ADDRESS;

            cur_bit_next        =   3'h7;
            cur_addr_next       =   2'b00;

            
            sda_write_next      =   1'b0;           //Set SDA Low
            
            write_cmpl_next     =   1'b0;

            delay_rst_next      =   1'b0;
        end  

        REPEATED_START : begin
            case(phy_state_reg)
                PHY_STATE_4 :     state_next = REPEATED_START; //Wait for SCL to drop low again
                //SCL drops low again so bring SDA high so I can bring it down again to send another Start bit
                PHY_STATE_1 : begin
                    state_next      =   REPEATED_START;
                    //Don't need to wait for the delay because it doesn't really matter
                    sda_write_next  =   1'b1;
                    delay_rst_next  =   1'b0;
                end
                //SCL Goes high, goooo looow on SDA to indicated a repeated start bit
                PHY_STATE_2 : begin
                    state_next          =   REPEATED_START;
                    //Reset the delay 
                    if(delay_rst_reg) begin
                        state_next      =   REPEATED_START;
                        delay_rst_next  =   1'b1;   
                    end 
                    //Don't need to do the final if, the fact next is set to last by default it will stay
                    //Inside of repeated start til after the delay triggers (Written while jamming to Anna Sun)
                    else if (!delayed_out) begin
                        //We are so back set the SDA to 0 to indicate a start and return to Write Address
                        state_next      =   WRITE_ADDRESS;
                        delay_rst_next  =   1'b0;
                        sda_write_next  =   1'b0;
                    end
                end
            endcase
        end

        WRITE_ADDRESS   : begin
            // //First time we enter turn of the CLK Reset
            // if(!rst_clkgen_reg) begin
            //     state_next          = WRITE_ADDRESS;
            //     rst_clkgen_next     = 1'b1;
            // end

            case(phy_state_reg) 
                PHY_IDLE      :     state_next = WRITE_ADDRESS;  //Still in startup
                PHY_READY     :     state_next = WRITE_ADDRESS;  //Still in startup
                PHY_START_BIT :     state_next = WRITE_ADDRESS;  //Still in startup
                
                //The Line is ready, wait for delay and set a SDA Bit.
                PHY_STATE_1 : begin 
                    //We got here after a successful ack, or a repeated start and need to turn off the reset on the delay
                    //Done so that we can get the same delay on the next bit 
                    if (delay_rst_reg) begin
                        state_next      =   WRITE_ADDRESS;
                        delay_rst_next  =   1'b1; //Turn 'er off m8
                    end
                    else if(!delayed_out) begin
                        state_next  =   WRITE_ADDRESS;
                        //Decrement Counter once in the Delay Period
                        if(dec_cur_bit_cnt) begin
                            dec_cur_bit_cnt_next    =   0;
                            cur_bit_next            =   cur_bit-1'b1;
                            //Done here and below, redundant but don't care, rather do it twice then not when I am suppose to
                            write_cmpl_next         =   1'b0;
                        end
                    end
                    else begin
                        if ( cur_bit != 0) begin
                            sda_write_next          =   addr_mem[cur_addr][cur_bit];
                            state_next              =   WRITE_ADDRESS;
                            //Done here and above, redundant but don't care, rather do it twice then not when I am suppose to
                            write_cmpl_next         =   1'b0;      

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
                        dec_cur_addr_cnt_next   =   1'b0;
                        //We finished all the sends Pog Champ
                        if(cur_addr == 2'b11) 
                            done_next       =   1'b1;
                        else 
                            cur_addr_next   =   cur_addr + 1'b1;
                    end    
                end    

                PHY_STATE_2 :    state_next = WAIT_FOR_ACK;

                //Now we are in the low after a complete Addr send. Release SDA and wait for it to go high again
                //Key to note, we waited for PHy1 and 2 because we had to let final bit propagate
                PHY_STATE_3 : begin
                    sda_t_next      =   1'b0;   //Release SDA
                    write_cmpl_next =   1'b0;   //We have successfully entered PHY3 so we can set this back to 0
                end

                PHY_STATE_4 : begin
                    //Wait the delay period so we are clearly inside of SCL before checking 
                    if(!delayed_out) 
                        state_next      =   WAIT_FOR_ACK; 
                    //Now we check to see the SDA has been held low by the Slave/Reciever
                    else begin
                        //Regardless of what happens we need to re-assert control over sda
                        sda_t_next      =   1'b1;       //Re-assert control over SDA
                        cur_bit_next    =   3'h7;       //Reset the Count regardless of where we go next
                        
                        //If successful ACK will be low
                        if(!sda_read_reg) begin    
                            //If we Completely finished the write go to STOP
                            if(done_next)
                                state_next      =   STOP;
                            else begin
                                state_next      =   WRITE_ADDRESS;  //LETS GOOOOO!!!!!!! *Soy Face*
                                delay_rst_next  =   1'b0;           //Allows for delay again by resetting it
                            end
                        end
                        //ACK Failed, its so jover
                        else begin
                            state_next      =   REPEATED_START;
                            delay_rst_next  =   1'b0;           //Allows for delay again by resetting it
                            //We failed so if we didn't get to the switch change go back to 0
                            //If we go through the switch address, go back to the the beginning of the address CLPD
                            cur_addr_next   =   (cur_addr < 2) ? (2'b00) : (2'b10);
                        end
                    end
                end
            endcase
        end


        /* Stop Condition. like in ACK we wait til the ACK clk rise ends, when scl goes low we SET SDA low
        *  When SCL falls, make sure SDA is low, then when it goes high set SDA to high to send start sig*/
        STOP : begin
            //Do the same thing as ACK wait for 4 to return to 1. set SDA to high
            case(phy_state_reg)
                PHY_STATE_4 : begin
                    state_next      =   STOP;
                    delay_rst_next  =   1'b0;
                end
                //SCL dropped after the ack bit. So set sda low so we can raise it again
                PHY_STATE_1 : begin
                    if(delay_rst_reg) begin
                        state_next      =   STOP;
                        delay_rst_next  =   1'b1;
                    end
                    //Don't need to do the final if, the fact next is set to last by default it will stay
                    //Inside of repeated start til after the delay triggers (Written while jamming to Chvrches)
                    else if (!delayed_out) begin
                        state_next      =   STOP;
                        delay_rst_next  =   1'b0;
                        sda_write_next  =   1'b0;
                    end
                end
                
                //SCL raises release SDA to send STOP
                PHY_STATE_2 : begin
                    sda_t_next  =  1'b0;
                    state_next  =  BOARD_LED;
                end

            endcase
        end

        //Literally everything is done just turn on the board LED and sit around
        BOARD_LED : begin
            done_led_on_next    =   1'b1;
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
        PHY_IDLE : begin
            if(bus_ready_reg == 1) 
                phy_state_next      =   PHY_IDLE;
            //When out of Reset we can go on to the READY
            else 
                phy_state_next      =   PHY_IDLE;
        end

        /** Ready to rock, indicates to the other state machine we are good to go and it can enter start
        *   Potentially in the future #TODO implement a check to ensure that the line is low, i.e. high for x cycles  */
        PHY_READY : begin
            //Wait til Filtered SDA_O goes low, while SCL is still high then go to Start State
            if( !(sda_read_reg) && scl_read_reg)
                phy_state_next      =   PHY_START_BIT;        
            else 
                phy_state_next      =   PHY_READY;
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

            //Unrelated if to check if we are inside of repeated start and if so to set Delay_in to 1
            if(state_reg == REPEATED_START) 
                delay_in_next = 1'b1;
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