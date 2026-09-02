
module pca_connector (
    input   wire            iClk,
    input   wire            iRst_n,
    input   wire [15:0]     cur_Addr,
    input   wire [7:0]      cur_Data_i,
    output  wire [7:0]      cur_Data_o,
    input   wire            cur_wr,
    input   wire            cur_rd,
    input   wire [7:0]      gpi_w [0:15],
    output  wire [7:0]      gpo_w [0:15] 
);

    logic [7:0] cur_Data_r      ;
    logic [7:0] gpo_r [0:15]    ;

    assign cur_Data_o = cur_Data_r;
    assign gpo_w = gpo_r;

    always @(posedge iClk) begin
        if (~iRst_n) begin
            for (int i = 0; i < 16; i++) begin
                gpo_r[i] <= 0;
            end
            cur_Data_r <= 0;
        end else begin
            if (cur_wr) begin
                if (cur_Addr >= 16 && cur_Addr < 32) begin
                    gpo_r[cur_Addr&'hf] <= cur_Data_i;
                end
            end
            if (cur_Addr >= 0 && cur_Addr < 16) begin
                cur_Data_r <= gpi_w[cur_Addr];
            end else if (cur_Addr >= 16 && cur_Addr < 32) begin
                cur_Data_r <= gpo_r[cur_Addr&'hf];
            end else begin
                cur_Data_r <= 8'h00;
            end
        end
    end

endmodule
