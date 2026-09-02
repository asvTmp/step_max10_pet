
module pca_i2c_gpio #(
    parameter DEVICE_ADDR      = 7'h55,    // device address Master needs to use to access this device
    parameter P_RV_OUTPUT      = 8'hFF,    // Reset Value for OUTPUT0 register (addr 0x2). Default value according to PCA9554 data-sheet
    parameter CC_FREQM         = 50        // CC_FREQ
) (
    input wire iClk,       // input clock for WDT (2MHz)
    input wire iRst_n,     // input reset signal (active low)
    input wire iSCL,       // input clock signal for I2C/SMBUS
    inout wire ioSDA,      // input data signal from

    input   wire [7:0]      gpi_w [0:15],
    output  wire [7:0]      gpo_w [0:15],

    output      oSmbAlert_n
  
);

    wire [15:0]     cur_Addr;
    wire [7:0]      cur_Data_i;
    wire [7:0]      cur_Data_o;
    wire            cur_wr;
    wire            cur_rd;

    pca_i2c_slave #(
        .DEVICE_ADDR(DEVICE_ADDR),
        .P_RV_OUTPUT(P_RV_OUTPUT),
        .CC_FREQM(CC_FREQM) 
    ) U_I2C_S0 (
        .iClk           (iClk),
        .iRst_n         (iRst_n),
        .iSCL           (iSCL),
        .ioSDA          (ioSDA),
        .cur_Addr       (cur_Addr),
        .cur_Data_i     (cur_Data_i),
        .cur_Data_o     (cur_Data_o),
        .cur_wr         (cur_wr),
        .cur_rd         (cur_rd),
        .oSmbAlert_n    (oSmbAlert_n) 
    );

    pca_connector U_CONNECTOR(
        .iClk           (iClk),
        .iRst_n         (iRst_n),
        .cur_Addr       (cur_Addr),
        .cur_Data_i     (cur_Data_o),
        .cur_Data_o     (cur_Data_i),
        .cur_wr         (cur_wr),
        .cur_rd         (cur_rd),
        .gpi_w          (gpi_w),
        .gpo_w          (gpo_w) 
    );


endmodule
