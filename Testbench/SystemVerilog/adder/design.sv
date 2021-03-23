// Author: Joel Mandebi
module adder
#(parameter WIDTH = 16)
(
  input clk,
  input rst,
  input dataIn,
  input [(WIDTH-1):0] opA,
  input [(WIDTH-1):0] opB,

  output reg [(2*WIDTH):0] result
);

always @(posedge clk or rst)
begin
  if(rst)
     result <= 0;
  else
    if(dataIn)
       result <= opA + opB;
  
 
end

endmodule