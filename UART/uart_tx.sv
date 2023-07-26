
module uart_tx (
	input logic clock, 
	nReset,
	//input logic Rx, 
	TxFifoLoad,
	input logic[7:0] TxData,
	output logic Tx,
	TxFifoEmpty,
	TxFifoFull
	//RxReady,
	//output logic [7:0] RxData
	);

// State
typedef enum  {IDLE, START_BIT, TRANSMIT, STOP_BIT, WAIT, WAIT1, DELAY} UART_transmit_state_t;
(* syn_encoding="compact" *)

UART_transmit_state_t transmitCurrentState, transmitNextState, transmitReturnState, transmitNextReturnState;

logic loadReturnState, TxBuffer, TxStart;

logic [0:1023] [7:0] TxFifoData;
logic [9:0] TxFifoReadPtr, TxFifoWritePtr;
logic [7:0] TxDataBuffer;

always_ff @(posedge clock, negedge nReset)
begin
	if (~nReset)
	begin
		for (integer i = 0; i < 1024; i++)
		begin
			TxFifoData[i] <= '0;
		end
		TxFifoReadPtr <= '0;
		TxFifoWritePtr <= '0;

		TxDataBuffer <= '0;
	end	
	else
	begin
		if (TxFifoLoad && !TxFifoFull)
		begin
			TxFifoData[TxFifoWritePtr] <= TxData;
			TxFifoWritePtr <= TxFifoWritePtr + 1;
		end

		if (TxStart)
		begin
			TxDataBuffer <= TxFifoData[TxFifoReadPtr];
			TxFifoReadPtr <= TxFifoReadPtr + 1;
		end
	end
end


always_comb 
begin
	TxFifoEmpty = 1'b0;
	TxFifoFull = 1'b0;

	if (TxFifoWritePtr == TxFifoReadPtr)
		TxFifoEmpty = 1'b1;

	if ((TxFifoWritePtr + 1) == TxFifoReadPtr)
		TxFifoFull = 1'b1;
end


always_ff @(posedge clock, negedge nReset)
begin
	if (~nReset)
		transmitCurrentState <= IDLE;
	else
		transmitCurrentState <= transmitNextState;
end	

always_ff @(posedge clock, negedge nReset)
begin
	if (~nReset)
		transmitReturnState <= IDLE;
	else if (loadReturnState)
	begin
		transmitReturnState <= transmitNextReturnState;
		Tx <= TxBuffer;
	end
end

logic loadBaudCounter;
logic[8:0] baudCounter, baudCounterVal;

always_ff @(posedge clock, negedge nReset)
begin
	if (~nReset)
		baudCounter <= '0;
	else if (loadBaudCounter)
		baudCounter <= baudCounterVal;
end

logic incrementDataCounter;
logic[2:0] dataCounter;

always_ff @(posedge clock, negedge nReset)
begin
	if (~nReset)
		dataCounter <= '0;
	else if (incrementDataCounter)
		dataCounter <= dataCounter + 1'b1;
end
		
always_comb
begin
	transmitNextState = transmitCurrentState;
	
	transmitNextReturnState = IDLE;
	loadReturnState = 1'b0;
	TxBuffer = 1'b1;
	incrementDataCounter = 1'b0;
	loadBaudCounter = 1'b0;
	baudCounterVal = '0;
	TxStart = 1'b0;
	
	case(transmitCurrentState)
		IDLE:
		begin
			
			if (!TxFifoEmpty)
			begin
				TxStart = 1'b1;
				transmitNextState = START_BIT;
			end
		end
		
		START_BIT:
		begin
			TxBuffer = 1'b0;
			transmitNextReturnState = TRANSMIT;
			loadReturnState = 1'b1;

			transmitNextState = DELAY;
		end

		TRANSMIT:
		begin
			TxBuffer = TxDataBuffer[dataCounter];
			incrementDataCounter = 1'b1;
			if (dataCounter == 3'b111)
				transmitNextReturnState = STOP_BIT;
			else
				transmitNextReturnState = TRANSMIT;
			loadReturnState = 1'b1;
			
			transmitNextState = DELAY;
		end
		
		STOP_BIT:
		begin
			TxBuffer = 1'b1;
			transmitNextReturnState = WAIT;
			loadReturnState = 1'b1;
			
			transmitNextState = DELAY;
		end

		WAIT: // stay high before next start bit
		begin
			TxBuffer = 1'b1;
			transmitNextReturnState = WAIT1;
			loadReturnState = 1'b1;
			
			transmitNextState = DELAY;
		end

		WAIT1: // stay high before next start bit
		begin
			TxBuffer = 1'b1;
			transmitNextReturnState = IDLE;
			loadReturnState = 1'b1;
			
			transmitNextState = DELAY;
		end
		
		DELAY:
		begin
			loadBaudCounter = 1'b1;
			baudCounterVal = baudCounter + 1;
			
			if (baudCounter == 9'd432) //50M / 115200 = 434.02, substract two for in and out of DELAY state
			begin
				transmitNextState = transmitReturnState;
				baudCounterVal = 0;
			end
		end
		
		default:
		begin
			transmitNextState = IDLE;
		end
		
	endcase	
	
end

/*
logic loadRxData;
logic[7:0] RxDataInput;

always_ff @(posedge clock, negedge nReset)
begin
	if (~nReset)
		RxData <= '0;
	else if(loadRxData)
		RxData <= RxDataInput;
end	

always_comb
begin
	RxReady = 1'b0;
	loadRxData = 1'b0;
end
*/
endmodule
