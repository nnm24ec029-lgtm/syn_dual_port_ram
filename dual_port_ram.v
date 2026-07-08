`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:Ashley Dsouza
//
// Create Date: 08.07.2026
// Design Name: Synchronous Dual port RAM
// Module Name: Dual_port_RAM
// Project Name: Memory Interface Verification System
/*
// Description:
The design of a synchronous(both port updates on same clock edge), parametrised Dual port RAM with active low reset.
In case of collision i.e A_en = 1 && B_en = 1 && We_A = 1 && Address_A == Address_B,
the Round_Robin_Arbiter assigns the priority.
Further additons : Double Data Rate, Error correction codes.
*/
////////////////////////////////////////////////////////////////////////////////////

module Sync_Dual_port_RAM #(parameter Width=8, Depth=32)(
input clk, RSTn,
//port A
output reg [Width-1:0]Data_Out_A,
input [Width-1:0]Data_In_A,
input A_en, We_A, Re_A,
input [$clog2(Depth)-1:0] Address_A,
//port B
output reg [Width-1:0]Data_Out_B,
input [Width-1:0]Data_In_B,
input B_en,We_B, Re_B,
input [$clog2(Depth)-1:0] Address_B
);
wire grant_A, grant_B;
wire request_A, request_B;
assign request_A = A_en && We_A;
assign request_B = B_en && We_B;
reg [Width-1:0] mem [0:Depth-1]; //array declaration

Round_Robin_Arb arb(
.grant_A(grant_A),.grant_B(grant_B),
.request_A(request_A),.request_B(request_B),
.clk(clk),.nRST(RSTn)
);  //instantiate Round Robin Arbiter
always @ (posedge clk)
begin
//reset behaviour
if (~RSTn)
begin
Data_Out_A <= 0;
Data_Out_B <= 0;
end
else
begin
if (grant_A)
begin
mem[Address_A] <= Data_In_A;
Data_Out_A <= Data_In_A;
end
else if (A_en && Re_A)
begin
Data_Out_A <= mem[Address_A];
end
if (grant_B)
begin
mem[Address_B] <= Data_In_B;
Data_Out_B <= Data_In_B;
end
else if (B_en && Re_B)
begin
Data_Out_B <= mem[Address_B];
end
end
end
endmodule
