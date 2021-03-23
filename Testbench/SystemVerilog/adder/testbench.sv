//Author: Joel Mandebi

`timescale 1ns / 1ps

localparam WIDTH = 32;
localparam DEBUG = 0;

interface adder_if(input bit clk);
  logic rst;
  logic dataIn;
  logic [(WIDTH-1):0] opA;
  logic [(WIDTH-1):0] opB;
  logic [(2*WIDTH):0] result;   
  int transId;
endinterface  



class Transaction;
  rand logic rst;
  rand logic dataIn;
  rand logic [(WIDTH-1):0] opA;
  rand logic [(WIDTH-1):0] opB;
  logic [(2*WIDTH):0] result; 
  int transId;
  
  function void print (string tag);
    $display("T=%0t [service=%s] --transId=%0d -- rst=%0d -- dataIn=%0d -- opA=0X%0h -- opB=0X%0h -- result=0X%0h ", $time,tag,transId,rst,dataIn,opA,opB,result);
  endfunction 
  
  function void print_scoreboard (string tag, logic [(2*WIDTH):0] expected);
    $display("T=%0t [SCOREBOARD] --%s --transId=%0d -- rst=%0d -- dataIn=%0d -- opA=0X%0h -- opB=0X%0h -- result=0X%0h -- Expected=0X%0h", $time,tag,transId,rst,dataIn,opA,opB,result,expected);
  endfunction
  
endclass


class Generator;
  mailbox drv_mbx;
  event drv_evt;
  int num_iteration;
  
  task run();
    $display("T=%0t [GENERATOR] starting ... \n",$time);
    
    num_iteration = $urandom_range(50,500);
    for(int i = 1; i < num_iteration; i++)
    begin
      Transaction t = new;
      t.randomize();
      t.transId = i;
      drv_mbx.put(t);
      if(DEBUG)
        t.print("GENERATOR");
      @(drv_evt);
    end  
  endtask  
endclass;

class Driver;
  mailbox drv_mbx;
  event drv_evt;  
  virtual adder_if vif;
  
  task run();
    $display("T=%0t [DRIVER] starting ...",$time);
    forever begin
      
       Transaction t = new;
       @(posedge vif.clk);
       drv_mbx.get(t);
       if(DEBUG)
        t.print("DRIVER");
       vif.rst = t.rst;
       vif.dataIn = t.dataIn;
       vif.opA = t.opA ;
       vif.opB = t.opB;
       vif.transId = t.transId;
      
      @(posedge vif.clk);
      ->drv_evt;
    end  
    
  endtask
 
endclass

class Monitor;
  virtual adder_if vif;
  mailbox scb_mbx;
  event drv_evt;
  
  task run();
    $display("T=%0t [MONITOR] starting ...",$time);
    
    forever begin
      
      Transaction t=new;
      @(drv_evt);
      //@(posedge vif.clk);
      t.rst = vif.rst;
      t.dataIn = vif.dataIn;
      t.opA = vif.opA;
      t.opB = vif.opB;
      t.transId = vif.transId;
      @(posedge vif.clk);
      t.result = vif.result;
      if(DEBUG)
       t.print("MONITOR");
      
      scb_mbx.put(t);
    end
  endtask
  
endclass

class Scoreboard;
  mailbox scb_mbx;
  int total_failures;
  
  logic [(2*WIDTH):0] prev_result;
  
  function logic [(2*WIDTH):0] add (logic [(WIDTH-1):0] opA, logic [(WIDTH-1):0] opB, logic rst, logic dataIn);
    if(rst==1) begin
       prev_result = 0;
       return 0;
    end 
    else begin
      if(dataIn==1)
        prev_result = opA + opB;
      
        return  prev_result;
     end    
  endfunction
  
  
  task run();
    $display("T=%0t [SCOREBOARD] starting ...",$time);
    
    forever begin
       Transaction t = new;
       scb_mbx.get(t);
      
      /*assert(t.result == add(t.opA,t.opB,t.rst,t.dataIn)) t.print_scoreboard("SUCCESS") ;
      else t.print_scoreboard("FAILURE"); */
    
      if(t.result == add(t.opA,t.opB,t.rst,t.dataIn)) 
        t.print_scoreboard("SUCCESS", prev_result);
      else begin
        t.print_scoreboard("FAILURE", prev_result);
        total_failures ++;
      end
    end
  endtask
  
  function void printFailure();
    
    $display("\n\n T=%0t [SCOREBOARD] TOTAL NUMBER OF FAILED TEST CASES = %0d\n",$time, total_failures);
  endfunction
  
endclass

class Environment;
  Generator    g0;
  Driver       d0;
  Monitor      m0;
  Scoreboard   s0;
  
  mailbox scb_mbx;
  mailbox drv_mbx;
  
  event drv_evt;  
  virtual adder_if vif;

  task run();
    $display("T=%0t [ENVIRONMENT] starting ...",$time);
    
    g0 = new;
    d0 = new;
    m0 = new;
    s0 = new;
    
    scb_mbx = new();
    drv_mbx = new();
    
    
    g0.drv_mbx = drv_mbx;
    d0.drv_mbx = drv_mbx;
    
    m0.scb_mbx = scb_mbx;
    s0.scb_mbx = scb_mbx;
    
    g0.drv_evt = drv_evt;
    d0.drv_evt = drv_evt;
    m0.drv_evt = drv_evt;
    
    d0.vif = vif;
    m0.vif = vif;
    
    s0.total_failures = 0;
    
    fork
      s0.run();
      m0.run();
      d0.run();
      g0.run();
    join_any
    
  endtask  
endclass


class test;
Environment e0;
virtual adder_if vif;
  
  task run();
    $display("T=%0t [TEST] starting ...",$time);
    
    e0 = new;
    
    e0.vif = vif;
    
    e0.run();
    
  endtask
  
endclass

module adder_tb;
  localparam period = 2;
  logic clk;
  test t0;

  adder_if add_if(clk);
  
  adder
  #(.WIDTH(WIDTH))
  DUT
  (
   .clk(clk),
   .rst(add_if.rst),
   .dataIn(add_if.dataIn),
   .opA(add_if.opA),
   .opB(add_if.opB),
   .result(add_if.result)
  );
   
   initial begin
      clk = 0;
      t0 = new();
      t0.vif = add_if; 
      t0.run();
      
     #(period*9)t0.e0.s0.printFailure();
     #(period*10) $stop;
     
   end
  
  always begin
    #(period/2) clk <= ~ clk;
  end
  
  
  initial begin
    $dumpfile("adder.vcd");
    $dumpvars;
  end
  
endmodule


