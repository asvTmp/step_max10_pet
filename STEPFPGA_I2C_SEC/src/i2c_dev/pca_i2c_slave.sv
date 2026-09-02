
module pca_i2c_slave #(
    parameter DEVICE_ADDR      = 7'h55,    // device address Master needs to use to access this device
    parameter P_RV_OUTPUT      = 8'hFF,    // Reset Value for OUTPUT0 register (addr 0x2). Default value according to PCA9554 data-sheet
    parameter CC_FREQM         = 50        // CC_FREQ
) (
    input wire iClk,       // input clock for WDT (2MHz)
    input wire iRst_n,     // input reset signal (active low)
    input wire iSCL,       // input clock signal for I2C/SMBUS
    inout wire ioSDA,      // input data signal from

    output wire [15:0]  cur_Addr,
    input  wire [7:0]   cur_Data_i,
    output wire [7:0]   cur_Data_o,
    output wire         cur_wr,
    output wire         cur_rd,

    output      oSmbAlert_n
   
);

    /////////////////////////////////////////////////////////////////////////////////////////////////
    //local param declarations
    ///////////////////////////////////

    localparam WDRT = (CC_FREQM == 50) ? 50000 : 2000;

    //FSM STATES      
    localparam INIT = 0;
    localparam DEV_ADDR = 1;
    localparam ACK_ST = 2;
    localparam REG_ADDR = 3;
    localparam REG_WRITE = 4;
    localparam REG_READ = 5;
    localparam MASTER_ACK = 6;

    /////////////////////////////////////////////////////////////////////////////////////////////////
    //Internal register declarations
    ///////////////////////////////////
    reg r_cur_wr;
    reg r_cur_rd;

    reg   rSDAo;                   //used to put the read data from regs (or the slave ACK) data


    reg   start_fsm;               //used to signal when a START condition has been detected
    reg   stop_fsm;                //used to signal when a STOP condition has been detected

    reg [2:0] rI2CFsm;             //I2C FSM, clocked by SCL input signal from link
    reg [2:0] fsm_prev_st;         //stores from where you are jumping into ACK_ST state

    reg [7:0] rDevAddr;            //Used to store the recieved Device Address from I2C/SMBus link. This needs
                                    //to be compared with current device address param to execute further or not

    reg [2:0] cnt;                 //used to parallelize/serialize data

    reg [15:0] rRegAddr_o;
    reg [15:0] rRegAddr;           //to store internal register address to be addressed

    reg       ack_ena;             //asserted when ACK should be sent to Master
    reg       read_ena;            //asserted during register read cycle. Together with reg_address will select the output data to be transmitted thru SDA inout

    reg [7:0] rInput;              //these are the 8 registers (8bits) the PCA9555 has, from ADDR = 0 to 7

    reg [7:0] rInput_meta = 8'h0;

    reg [7:0] rInput_sync = 8'h0;

    reg [7:0] rInput_t;            //bkup read data to know when there is a change on inputs to generate or not the alert_n signal 

    reg [7:0] rOutput;             //write/read register thru I2C/SMBus I/F. to Port 0 output pins

    reg       proxy_bit;       //writes are performed to this bit, and it will pass to the right register filtered by the stop bit (if stop bit is asserted, proxy bit won't be written to internal register
    reg       filter_flag;     //when in the write_reg, we turn on this as soon as we receive the 1st data, flag is cleared either at ACK_ST or at INIT. This helps keeping input data to be then validated by !stop_fsm flag
                                //before it is written

    reg       read_flag;       //it is used to distinguish if it is the 1st byte or 2nd byte of the read command (to know where to end the read)

    reg       ack_out;         //indicates acknowledge is asserted and the inout data pin (ioSDA) is as output 
    reg       read_out;        //indicates data is being read and the inout data pin (ioSDA) is as output 

    reg       start_clr_n;     //after start condition is detected, as it's latched, needs to be cleared
    wire      start_rst_n;     //these 2 signals are for this purpose

    wire      wSmbAlert_n;    //used to distinguish if any input changed its value and alert needs to be asserted

    wire      wDoneTimer1ms;

    reg [2:0] scl_t;
    reg [2:0] sda_t;
    reg       scl_rise;
    reg       scl_fall;

    //////////////////////////

    always @(posedge iClk, negedge iRst_n) begin
        if (~iRst_n) begin
            scl_t <= 3'b111;
            scl_rise <= 1'b0;
            scl_fall <= 1'b0;

            sda_t <= 3'b111;

        end else begin
            scl_t[0] <= iSCL;
            scl_t[1] <= scl_t[0];
            scl_t[2] <= scl_t[1];
            scl_rise <= !scl_t[2] && scl_t[1];

            scl_fall <= scl_t[2] && !scl_t[1];

            ///

            sda_t[0] <= ioSDA;
            sda_t[1] <= sda_t[0];
            if (sda_t[1] == sda_t[0]) begin
                sda_t[2] <= sda_t[1];
            end
        end
    end

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    //1-msec Timer, started when read_out or ack_out are HIGH, clear when both low
    delay_for_pca #(.COUNT(WDRT)) Timer1ms
    (
        .iClk(iClk),
        .iRst(iRst_n),
        .iStart(read_out || ack_out),
        .iClrCnt(1'b0),
        .oDone(wDoneTimer1ms)
    );
   
   ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   
    //registering the ioData Ports 0&1 into the respective input register port
    always @(negedge iSCL, negedge iRst_n) begin
        if (!iRst_n) begin
            rInput  <= 8'h00;
        end else begin
            rInput  <= cur_Data_i;
        end
    end

    //used as the reset for the start_fsm flip-flop, combining the regular Rst with the condition when the start was detected and processed
    //to avoid start indication to remain longer and be falsely seen after the current operation ends
    assign start_rst_n = !iRst_n || !start_clr_n;
   
    //This is to detect the start condition in the I2C/SMBUS link
    //We are using data line as the clock of the flip flop (negedge), and the clock as the enable to set a HIGH or LOW value at the outupt of it
    //The effect is that flip-flop output will be HIGH if a START condition is detected, LOW otherwise
    always @(negedge sda_t[2], posedge start_rst_n) begin
        if (start_rst_n) begin
            start_fsm <= 1'b0;
        end else begin
            if (iSCL) begin
                start_fsm <= 1'b1;                     //asserts when I2C start condition is detected: a change on data signal (from HIGH to LOW) while clk is HIGH
            end
        end // else: !if(~iRst_n)
    end // always @ (negedge ioSDA, negedge iRst_n)

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    //This is to detect the stop condition in the I2C/SMBUS link
    //We are using data line as the clock of the flip flop (posedge), and the clock as the enable to set a HIGH or LOW value at the outupt of it
    //The effect is that flip-flop output will be HIGH if a STOP condition is detected, LOW otherwise
    always @(posedge sda_t[2], posedge start_fsm) begin
        if (start_fsm) begin
            stop_fsm <= 1'b0;
        end else begin
            if (iSCL) begin
                stop_fsm <= 1'b1;                     //asserts when I2C start condition is detected: a change on data signal (from HIGH to LOW) while clk is HIGH
            end else begin
                stop_fsm <= 1'b0;                     //deasseted the rest of the times
            end
        end // else: !if(~iRst_n)
    end // always @ (negedge ioSDA, negedge iRst_n)

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //this is the main FSM for the I2C/SMBUS master and PCA9555 althogether
    //this has both the read control and the write portion 
    /////////////////////////////////////////////////////////////////////////

    assign cur_Addr = rRegAddr_o;
    assign cur_Data_o = rOutput;
    assign cur_wr = r_cur_wr & scl_rise;
    assign cur_rd = r_cur_rd & scl_rise;

    always @(posedge iClk, negedge iRst_n) begin
        if (~iRst_n) begin
            rI2CFsm <= INIT;                           //INIT state waits for START condition to go forward
            fsm_prev_st <= INIT;
            rDevAddr <= 8'h00;
            rRegAddr <= 16'h00;
            rRegAddr_o <= 16'h0;
            cnt <= 3'h7;
            ack_ena <= 1'b0;
            read_ena <= 1'b0;
            rOutput  <= P_RV_OUTPUT;
            start_clr_n <= 1'b1;
            proxy_bit <= 1'b0;
            filter_flag <= 1'b0;
            read_flag <= 1'b1;
            r_cur_wr <= 1'b0;
            r_cur_rd <= 1'b0;
        end else begin
            // r_cur_wr <= 1'b0;
            // r_cur_rd <= 1'b0;
            if (scl_rise) begin
                //if at any moment a STOP or a START are received, FSM needs to act properly, so these conditions are placed here to be checked at every cycle (every state)
                if (stop_fsm == 1'b1) begin //stop indication received
                    rI2CFsm <= INIT;    
                    cnt <= 3'h7;
                    fsm_prev_st <= INIT;
                    rDevAddr <= 8'h00;
                    rRegAddr <= 16'h00;
                    rRegAddr_o <= 16'h0;
                    cnt <= 3'h7;
                    ack_ena <= 1'b0;
                    read_ena <= 1'b0;
                    proxy_bit <= 1'b0;
                    r_cur_wr <= 1'b0;
                    r_cur_rd <= 1'b0;
                end else if (start_fsm == 1'b1 && rI2CFsm != INIT) begin //restart received
                    rDevAddr[7] <= sda_t[2];
                    rI2CFsm <= DEV_ADDR;
                    fsm_prev_st <= DEV_ADDR;
                    cnt <= 3'h6;
                    start_clr_n <= 1'b0;
                    ack_ena <= 1'b0;
                    read_ena <= 1'b0;
                    r_cur_wr <= 1'b0;
                    r_cur_rd <= 1'b0;
                end else begin                      //FSM logic begins here
                    case (rI2CFsm)
                        INIT: begin
                            filter_flag <= 1'b0;
                            start_clr_n <= 1'b1;
                            ack_ena <= 1'b0;
                            read_ena <= 1'b0;
                            rDevAddr[cnt] <= sda_t[2];
                            read_flag <= 1'b0;                    //clearing read flag, in case command is a read
                            proxy_bit <= 1'b1;
                            if (start_fsm == 1'b1) begin
                                cnt <= cnt - 3'h1;
                                rI2CFsm <= DEV_ADDR;            //if START happened, go to DEV_ADDR state and decrease counter
                                start_clr_n <= 1'b0;            //start condition detected, clearing the flag
                                fsm_prev_st <= rI2CFsm;
                            end
                        end
                        DEV_ADDR: begin
                            start_clr_n <= 1'b1;
                            rDevAddr[cnt] <= sda_t[2];
                            if (cnt == 3'h0) begin
                                cnt <= 3'h7;                                //last bit read, need to restart cnt value to 7
                                if (rDevAddr[7:1] == DEVICE_ADDR) begin     //if read 7-bit addr same as device addr, send ACK & continue with port address read
                                    fsm_prev_st <= rI2CFsm;                 //as we go to ACK state, we store from where we jumped, so we know where to go next
                                    rI2CFsm <= ACK_ST; 
                                    ack_ena <= 1'b1;                        //enables the acknoledge to be set
                                end else begin
                                    rI2CFsm <= INIT;                        //else, means bus access not for this device and need to clear up and
                                    rDevAddr <= 8'h00;                      //go back to be ready for next cycle
                                end
                            end else begin
                                cnt <= cnt - 3'h1;                          //keep decrementing counter and storing ADDR bits in register
                                rI2CFsm <= DEV_ADDR;
                            end
                        end // case: DEV_ADDR
                        ACK_ST:begin
                            ack_ena <= 1'b0;                        
                            case(fsm_prev_st)
                                DEV_ADDR: begin
                                    if (rDevAddr[0] == 1'b0) begin          //write cycle
                                        rI2CFsm <= REG_ADDR;                //then go to get register address state
                                        read_ena <= 1'b0;
                                        rRegAddr <= 16'h00;
                                        rRegAddr_o <= 16'h0;
                                    end else begin
                                        rI2CFsm <= REG_READ;                //then go to get register address state
                                        r_cur_rd <= 1'b1;
                                        read_ena <= 1'b1;
                                    end
                                end
                                REG_ADDR: begin                             //if we were here, it is a write cycle
                                    rI2CFsm <= REG_WRITE;                   //then go to get register address state
                                    rRegAddr_o <= rRegAddr;
                                end
                                REG_WRITE:begin
                                    rI2CFsm <= REG_WRITE;                   //if came from WRITE_REG st and no STOP nor START condition detected, keep go back to WRITE REG for more data to be read (and toggle LSb of reg-addr
                                    filter_flag <= 1'b0;
                                    rRegAddr <= rRegAddr + 1;            //if continue writing, change to the pair complement address
                                    rRegAddr_o <= rRegAddr;
                                    rOutput[0] <= proxy_bit;
                                    r_cur_wr <= 1'b1;
                                end // case: WRITE_REG
                                default: begin
                                    rI2CFsm <= INIT;
                                    cnt <= 3'h7;
                                    rRegAddr <= 16'h00;
                                    rRegAddr_o <= 16'h00;
                                    rDevAddr <= 8'h00;
                                    start_clr_n <= 1'b0;
                                end
                            endcase // case (fsm_prev_st)
                        end // case: ACK_ST
                        REG_ADDR: begin     //need to gather port address to know to which port will address
                            rRegAddr[cnt] <= sda_t[2];
                            if (cnt == 3'h0) begin      //if all bits are read, go to ack state
                                cnt <= 3'h7;                  
                                ack_ena <= 1'b1;
                                fsm_prev_st <= rI2CFsm;        //preserve present state in fsm_prev_st to know where to go next after ack
                                rI2CFsm <= ACK_ST;
                            end else begin
                                ack_ena <= 1'b0;
                                cnt <= cnt - 3'h1;
                                rI2CFsm <= REG_ADDR;
                            end
                        end // case: REG_ADDR
                        REG_WRITE: begin
                            proxy_bit <= sda_t[2];
                            filter_flag <= 1'b1;
                            r_cur_wr <= 1'b0;
                            if (cnt == 3'h0) begin
                                cnt <= 3'h7;
                                rI2CFsm <= ACK_ST;
                                fsm_prev_st <= rI2CFsm;
                                ack_ena <= 1'b1;
                            end else begin
                                cnt <= cnt - 3'h1;
                                rI2CFsm <= REG_WRITE;
                            end // else: !if(cnt == 3'h0)
                            if (filter_flag && !stop_fsm) begin
                                rOutput[cnt + 1] <= proxy_bit;
                            end // if (filter_flag)
                        end // case: REG_WRITE
                        REG_READ: begin
                            r_cur_rd <= 1'b0;
                            if (cnt == 3'h0) begin
                                cnt <= 3'h7;
                                rI2CFsm <= MASTER_ACK;
                                read_ena <= 1'b0;
                            end else begin
                                cnt <= cnt - 3'h1;
                                read_ena <= 1'b1;
                            end
                        end // case: REG_READ
                        MASTER_ACK: begin
                            if (sda_t[2]) begin
                                rI2CFsm <= INIT;
                                read_ena <= 1'b0;
                                start_clr_n <= 1'b0;
                            end else begin
                                // rRegAddr[0] <= ~rRegAddr[0];          //master acknowledge received, toggling LSb of register address to send next register data
                                rRegAddr <= rRegAddr + 1;               //master acknowledge received, toggling LSb of register address to send next register data
                                rRegAddr_o <= rRegAddr + 1;
                                rI2CFsm <= REG_READ;                    //if we do not get the NACK from Master, we do a continuous read by going back to REG_READ and we switch to the pair address
                                r_cur_rd <= 1'b1;
                                read_ena <= 1'b1;                     
                            end
                        end //case: MASTER_ACK
                        default:begin
                            cnt <= 3'h7;
                            rI2CFsm <= INIT;              //something went wrong, going back to INIT state
                            rRegAddr <= 16'h00;
                            rRegAddr_o <= 16'h00;
                            rDevAddr <= 8'h00;
                            start_clr_n <= 1'b0;
                        end
                    endcase // case (rI2CFsm)
                end // else: !if(start_fsm == 1'b1)
            end // if (scl_rise) begin 
        end // else: !if(~iRst_n)
    end // always @ (posedge iSCL, negedge iRst_n)

    wire read_rst_n;
    assign read_rst_n = iRst_n && !wDoneTimer1ms;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //this logic helps to output data into SDA signal using falling edge of the SCL clock signal (read data)
    //however all control signals come from our main FSM clocked with the same SCL clock signal, but with the rising edge
    //////////////////////////////////////////////////////////////////

    always @(posedge iClk, negedge read_rst_n) begin
        if (~read_rst_n) begin
            rSDAo <= 1'b1;
            rInput_t <= 8'h00;                    //reset value the same as rInput0/rInput1 respectively
            ack_out <= 1'b0;
            read_out <= 1'b0;
        end else if (scl_fall) begin
            if (ack_ena == 1'b1) begin
                rSDAo <= 1'b0;                   //acknoledge to master
                ack_out <= 1'b1;                 //this enables inout pin as output for the acknowledge bit to be seen by master
            end else if (read_ena && !stop_fsm) begin
                read_out <= 1'b1;               //this enables inout pin as output for reading data to be seen by master
                ack_out <= 1'b0;
                rInput_t[cnt] <= rInput_sync[cnt];
                rSDAo <= rInput_sync[cnt];
            end else begin // if (read_ena == 1'b1)
                rSDAo <= 1'b1;                    //if no read operation, the pin is released (by driving a HIGH which will be converted into HIGHZ
                ack_out <= 1'b0;                  //no enable is asserted
                read_out <= 1'b0;
            end // else: !if(read_ena == 1'b1)
        end // if (scl_fall)
    end // always @ (negedge iSCL, negedge iRst_n)

                                                                                //if read cycle or slave ack enable is asserted, then the output should be driving what the rSDAo has
    assign ioSDA = (read_out || ack_out) ? (rSDAo ? 1'bZ: 1'b0) : 1'bZ;         //considering always a HIGH value should be HIGHZ to the output so we have an open-drain signal

    assign wSmbAlert_n  = ((rInput_t)  == (cur_Data_i)) ? 1'b1 : 1'b0;        //if input data (read from pins) is different that last read data, need to assert an alert id to SMB Master
                                                                                                    //if input is changed back to previous state before it is read, alert is also de-asserted  

    assign oSmbAlert_n = (wSmbAlert_n) ? 1'bZ : 1'b0;              //as we have 2 registers here, we check on both and merge info into 1 output

    always @(posedge iClk) begin
        rInput_meta  <= rInput;
        rInput_sync  <= rInput_meta;        // sync
    end

endmodule // pca_i2c_slave

module delay_for_pca # //% Parameterizable Delay Module<br>
(                                
    parameter                   COUNT  =   1 //% Total count
) (
                                
    input wire      iClk,       // Clock Input
    input wire      iRst,       // Asynchronous Reset Input
    input wire      iStart,     // Start Delay Input Signal
    input wire      iClrCnt,    // Clear Count signal 
    output wire     oDone       // Done Flag Output
);

    function integer clog2;
        input integer value;
        begin
            value = (value > 1) ? value-1 : 1;
            for (clog2=0; value>0; clog2=clog2+1)
                value = value>>1;
        end
    endfunction

    localparam TOTAL_BITS = clog2(COUNT);

    reg                     rDone;
    reg [(TOTAL_BITS-1):0]  rCount;

    always @(posedge iClk or negedge iRst) begin
        if (~iRst) begin                            //Reset
            rDone   <=   1'b0;                      //Done flag
            rCount  <=   {TOTAL_BITS{1'b0}};        //Counter
        end else begin
            if(~iStart || iClrCnt) begin            //If iStart is LOW or iClrCnt is HIGH, output goes low as well
                rDone   <= 1'b0;
                rCount  <= {TOTAL_BITS{1'b0}};
            end else if (COUNT-1 > rCount) begin    //Output set as high when counter reaches expected value
                rDone   <= 1'b0;
                rCount  <= rCount + 1'b1;
            end else begin                          //Output low and counter increases if no conditions were met
                rDone   <= 1'b1;
                rCount  <= rCount;
            end
        end
    end

    assign oDone = rDone;

endmodule
