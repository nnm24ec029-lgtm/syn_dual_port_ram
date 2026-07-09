`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Ashwin Nayak
// 
// Create Date: 21.04.2026 14:24:17
// Design Name: Synchronous Dual port RAM
// Module Name: Sync_Dual_port_Ram_tb
// Project Name: Memory Interface Verification System
/* 
// Description: 
1.Interface:
-Declares the signals and modports along with assertions.
-virtual interface is an handle/pointer to an actual interface instance. 
-vir_if lets classes access and drive interface signals.
-In TB module actual interface instance is created, then passed to the driver/monitor.

2.Testing Environment
-class transaction defines what a transaction packet must conation.
-class generator creates random transactions of type txn and using mailbox the txn is sent to driver
-class driver drives the signals to DUT through interface.
-DUT sends the signals to monitor to observe i/p and o/p through interface.
-Monitor observes and sends the processed txn to scorevoard through mailbox.
-scoreboard recives and checks the correctness of DUT with a associative array model of Dual port RAM and displays PASS/FAIL.
-The testbench creates objects and runs tasks in parallel.

3.Covergroup: 
-Port A write only
-Port B write only
-Both ports write simultaneously
-Port A read
-Port B read
-Both ports active simultaneously
-Only port A enabled
-Only port B enabled
-Both ports enabled 

4.Assertions:(inside interface)
-If Port A writes, next cycle output must reflect that data
-After reset, outputs must be 0
-On collision, Port A must win
*/ 
//////////////////////////////////////////////////////////////////////////////////

//interface 
interface DP_ram_inf #(parameter Width=8,Depth=32 );
                     logic clk, RSTn;
                     logic A_en, We_A, Re_A;
                     logic B_en, We_B, Re_B;
                     logic [$clog2(Depth)-1:0] Address_A, Address_B;
                     logic [Width-1:0] Data_In_A, Data_In_B;
                     logic [Width-1:0] Data_Out_A, Data_Out_B;
                     
                    modport driver (input clk, input RSTn,
                                    output  A_en, We_A, Re_A, B_en, We_B, Re_B,
                                    output Data_In_A, Data_In_B,
                                    output  Address_A, Address_B); 
                    modport monitor (input clk, input RSTn,
                                    input Data_Out_A, Data_Out_B,
                                    input  A_en, We_A, Re_A, B_en, We_B, Re_B,
                                    input  Data_In_A, Data_In_B,
                                    input  Address_A, Address_B);
                                    
                  
                  property reset_check; // if RSTn =0; o/p data = 0 next cycle (sync behaviour)
                        @(posedge clk) (!RSTn) |=> (Data_Out_A == 0 && Data_Out_B == 0);
                  endproperty
                  assert property(reset_check) 
                    else $display("!!! RESET ASSERTION FAILED !!!");
                  
                  property collision;
                        @(posedge clk) (A_en && We_A && (Address_A == Address_B)) |=> ( Data_Out_B == $past(Data_Out_B));
                  endproperty
                  assert property (collision) 
                    else $display("COLLISION DETECTED - PORT A WINS!!!");
    
endinterface 

package dual_port_ram;

localparam  Width=8;
localparam Depth=32;

    class transaction;
    
        rand logic [Width-1:0] Data_In_A,Data_In_B; //I/P signals
        rand bit A_en,We_A, Re_A,B_en,We_B, Re_B; // enable signals
        rand logic [$clog2(Depth)-1:0] Address_A, Address_B; //address signals 
        logic [Width-1:0] Data_Out_A, Data_Out_B;//O/P signals
        
        localparam  N = 30;// No of transaction packets 
        
        constraint valid_addr {
                               Address_A < Depth;
                               Address_B < Depth;
                               }// to make addresses stay within valid range
        
        function void display();//display function
            $display("\n---------------------I/P Packet--------------------\n");
            $display("[%0t] | TRANSACTION PACKET - PORT A \n  A_en = %0d | We_A = %0d | Re_A : %0d \n ", $time, A_en,We_A, Re_A);
            
            $display("[%0t] | TRANSACTION PACKET PORT B:\n B_en = %0d | We_B = %0d | Re_B :%0d\n",$time,B_en,We_B, Re_B);    
                
            $display("[%0t] | DATA_IN_A : %d | DATA_IN_B : %d\n Address of PORT A :%d| Address of PORT B :%d\n",$time,Data_In_A,Data_In_B,Address_A, Address_B);
            $display("\n---------------------END OF I/P Packet--------------------\n");
        endfunction 
        
        function void show();//O/P DATA is not randomized. So its preffered not to display inside packet.
            $display("OUTPUT DATA @ [%0t] | DATA_OUT_A : %d | DATA_OUT_B : %d\n",$time,Data_Out_A,Data_Out_B);
        endfunction 
        
    endclass
    
    class generator;
    
        mailbox RAM_mail;// mailbox between generator and driver.
        transaction txn;// transaction handle 
       
        function new(); //constructor
            txn = new();
            RAM_mail = new();
        endfunction
         
        task gen_txn(); // loop to generate random transactions and put into mailbox.
            repeat(txn.N)
            begin
                txn = new(); //gen new obj everytime
                txn.randomize();//randomize
                RAM_mail.put(txn);//put into mailbox
                txn.display();  //display
            end
        endtask
        
    endclass
    
    class driver;
    
        mailbox RAM_mail;// mailbox between generator and driver.
        transaction txn;// transaction handle
        virtual DP_ram_inf #(8,32) vir_if;//points to actual interface and lets driver access interface signals 
        
        task dri_txn();
            repeat(txn.N)
            begin
                 RAM_mail.get(txn);// get the transactions from generator
                 @(posedge vir_if.clk);
                 
                 vir_if.A_en = txn.A_en;
                 vir_if.B_en = txn.B_en;
                 vir_if.We_A = txn.We_A;
                 vir_if.We_B = txn.We_B;
                 vir_if.Re_A = txn.Re_A;
                 vir_if.Re_B = txn.Re_B;
                 vir_if.Address_A = txn.Address_A;
                 vir_if.Address_B = txn.Address_B; 
                 vir_if.Data_In_A = txn.Data_In_A;
                 vir_if.Data_In_B = txn.Data_In_B;
            end
        endtask 
        
    endclass
    
    class monitor;
    
        transaction txn;
        mailbox RAM_mailbox;//mailbox between monitor and scoreboard 
        virtual DP_ram_inf #(8,32) vir_if;//points to actual interface and lets monitor access interface signals 
            function new();//constructor
                RAM_mailbox =new();
            endfunction 

            task put_txn; //put to scoreboard
                repeat(txn.N)
                begin
                    @(negedge vir_if.clk);//sample and put at negedge 
                    txn = new();
                    txn.Data_Out_A = vir_if.Data_Out_A;
                    txn.Data_Out_B = vir_if.Data_Out_B;
                    txn.A_en = vir_if.A_en;
                    txn.B_en = vir_if.B_en;
                    txn.We_A = vir_if.We_A;
                    txn.We_B = vir_if.We_B;
                    txn.Re_A = vir_if.Re_A;
                    txn.Re_B = vir_if.Re_B;
                    txn.Address_A = vir_if.Address_A;
                    txn.Address_B = vir_if.Address_B; 
                    txn.Data_In_A = vir_if.Data_In_A;
                    txn.Data_In_B = vir_if.Data_In_B;
                    RAM_mailbox.put(txn);
                    txn.show();
                end
            endtask
            
    endclass
    
    class scoreboard;
   
        transaction txn;
        mailbox RAM_mailbox;//mailbox between monitor and scoreboard 
        logic [Width-1:0] mem_model [int];// Associative array as RAM model
        logic [Width-1:0] exp_A,exp_B;
        
        function new();
            RAM_mailbox = new();
        endfunction 
        
        task get_txn;
            repeat (txn.N)
            begin
                RAM_mailbox.get(txn);
                //collision condition
                $display("------------[%0t] SCOREBOARD RESULT---------------", $time);
                if (txn.A_en && txn.B_en && txn.We_A && txn.We_B && txn.Address_A == txn.Address_B)
                begin
                    mem_model[txn.Address_A] = txn.Data_In_A;
                    $display("COLLISION - PORT A WINS : Addr[%0d]", txn.Address_A);
                end
                
                else
                begin
                    if (txn.A_en && txn.We_A)
                        begin
                            mem_model[txn.Address_A] = txn.Data_In_A;
                            $display("PORT A WRITE : Addr[%0d] = %0d", txn.Address_A, txn.Data_In_A); 
                        end
                    if (txn.B_en && txn.We_B)
                        begin
                            mem_model[txn.Address_B] = txn.Data_In_B;
                            $display("PORT B WRITE : Addr[%0d] = %0d", txn.Address_B, txn.Data_In_B); 
                        end
                    end
                    if (txn.A_en && txn.Re_A) 
                    begin
                        if (mem_model.exists(txn.Address_A))
                        begin
                            exp_A = mem_model[txn.Address_A];
                        end
                        else 
                        begin  
                            exp_A = 0;
                        end
                    end
                    if (txn.B_en && txn.Re_B) 
                    begin
                        if (mem_model.exists(txn.Address_B))
                        begin
                            exp_B = mem_model[txn.Address_B];
                        end
                        else 
                        begin  
                            exp_B = 0;
                        end
                    end
                 
                 // Compare PORT A
                if (txn.A_en && txn.Re_A) 
                begin
                    if (txn.Data_Out_A !== exp_A)
                    begin
                        $display("!!! FAIL !!! PORT A READ | Addr[%0d] | Expected: %0d | Got: %0d",txn.Address_A, exp_A, txn.Data_Out_A);
                    end
                     else
                     begin
                        $display("*** PASS *** PORT A READ | Addr[%0d] | Data: %0d",txn.Address_A, txn.Data_Out_A);
                    end
                end

                // Compare PORT B
                if (txn.B_en && txn.Re_B)
                begin
                    if (txn.Data_Out_B !== exp_B) 
                    begin
                        $display("!!! FAIL !!! PORT B READ | Addr[%0d] | Expected: %0d | Got: %0d",txn.Address_B, exp_B, txn.Data_Out_B); 
                    end
                    else
                    begin
                    $display("*** PASS *** PORT B READ | Addr[%0d] | Data: %0d",txn.Address_B, txn.Data_Out_B);
                    end
                end  
            end
        endtask
    endclass
     
endpackage

import dual_port_ram::*; //import the package

module Sync_Dual_port_Ram_tb();

    reg clk = 0;
    reg RSTn = 0; // declare the signals which arent controlled by RAM (foreign signals)
    
    DP_ram_inf #(8,32) ram_if();//virtual interface declaration
    assign ram_if.clk = clk;
    assign ram_if.RSTn = RSTn;
    
    Sync_Dual_port_RAM #(8,32) DUT(
                                .clk(ram_if.clk),.RSTn(ram_if.RSTn),
                                .A_en(ram_if.A_en),.We_A(ram_if.We_A),.Re_A(ram_if.Re_A),
                                .B_en(ram_if.B_en),.We_B(ram_if.We_B),.Re_B(ram_if.Re_B),
                                .Data_In_A(ram_if.Data_In_A),.Data_In_B(ram_if.Data_In_B),
                                .Address_A(ram_if.Address_A),.Address_B(ram_if.Address_B),
                                .Data_Out_A(ram_if.Data_Out_A),.Data_Out_B(ram_if.Data_Out_B)
                                ); //intsantiate the DUT through interface 
                                
   covergroup cover_RAM @(posedge clk);
                                        
        cp_we_a : coverpoint ram_if.We_A{
                                         bins write = {1};
                                         bins no_write = {0};
                                         }
        cp_we_b : coverpoint ram_if.We_B{
                                         bins write = {1};
                                          bins no_write = {0};
                                          }
        cross cp_we_a,cp_we_b;// checks all combinations of both We_A and We_B
        
        cp_re_a : coverpoint ram_if.Re_A{
                                         bins read = {1};
                                         bins no_read = {0};
                                         }
        cp_re_b : coverpoint ram_if.Re_B{            
                                         bins read = {1};
                                         bins no_read = {0};
                                         }
        cross cp_re_a,cp_re_b;// checks all combinations of both Re_A AND Re_B 
                                           
        cp_en_a : coverpoint ram_if.A_en{
                                         bins enable = {1};
                                         bins not_enable = {0};
                                         }
        cp_en_b : coverpoint ram_if.B_en{
                                         bins enable = {1};
                                         bins not_enable = {0};
                                         }
       cross cp_en_a,cp_en_b;// checks all combinations of both A_en and B_en
                                                                                 
   endgroup
   
                                cover_RAM cg = new();
                                
                                always #5 clk = ~clk; //clock generation
                                initial
                                begin
                                    RSTn = 0;
                                    #20;
                                    RSTn = 1;
                                end// assert active low reset 
                                initial
                                begin
                                    //create handles 
                                    static generator gen = new();
                                    static driver dri = new();
                                    static monitor mon = new();
                                    static scoreboard scb = new();
                                    static mailbox gen_dri_mail = new();
                                    static mailbox mon_scb_mail = new();
                                   
                                    mon.RAM_mailbox = mon_scb_mail;
                                    scb.RAM_mailbox = mon_scb_mail;
                                    
                                    dri.vir_if = ram_if; // connect virtual interface
                                    mon.vir_if = ram_if; // connect virtual interface
                                    
                                    
                                    gen.RAM_mail = gen_dri_mail;
                                    dri.RAM_mail = gen_dri_mail;
                                    @(posedge ram_if.RSTn);
                                    //tasks run in parallel.
                                    fork
                                        gen.gen_txn();
                                        dri.dri_txn();
                                        mon.put_txn();    
                                        scb.get_txn();    
                                    join
                                    $finish;
                                end
                                initial
                                begin
                                    $dumpfile("dump.vcd");
                                    $dumpvars(0, Sync_Dual_port_Ram_tb);
                                end
endmodule
