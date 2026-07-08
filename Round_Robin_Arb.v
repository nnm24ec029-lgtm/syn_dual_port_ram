`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ashley Dsouza
// 
// Create Date: 07.07.2026 23:17:07
// Design Name: 
// Module Name: Round_Robin_Arb
// Project Name: 
// Target Devices: 
// Tool Versions: 
/*
// Description: 
Arbitration = deciding which request gets access when multiple requests conflict.
The round Robin Arbiter Rotates priority among requesters
*/
// 
//////////////////////////////////////////////////////////////////////////////////


module Round_Robin_Arb(
                        output reg grant_A, grant_B,
                        input request_A, request_B,clk,nRST
                        );
                        reg last_grant;//last_grant=0 ->A; last_grant =1 ->B
                        
                        always @(*)
                        begin
                                grant_A = 1'b0;
                                grant_B = 1'b0;
                                last_grant = 1'b0;
                            
                                if (request_A && !request_B)
                                begin
                                    grant_A <= 1'b1;// A wins
                                end
                                else if (!request_A && request_B)
                                begin
                                    grant_B <= 1'b1;// B wins
                                end
                                else if (request_A && request_B)
                                begin
                                    // round robin using last_grant
                                    if (last_grant == 1'b0)
                                    begin 
                                        grant_B <= 1'b1;// B wins
                                    end
                                    else 
                                    begin
                                        grant_A <= 1'b1;// A wins
                                    end
                                end
                            end
                            always @(posedge clk or negedge nRST)
                            begin
                                if (!nRST)
                                    last_grant <= 0;
                                else if (request_A && request_B)
                                begin
                                    if (last_grant == 0) last_grant <= 1;
                                    else last_grant <= 0;
                                end
                            end
endmodule
