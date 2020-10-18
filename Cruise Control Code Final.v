//Digital Logic - Cruise Control Project
//Smith, Pham, Nguyen
//12/9/2019

//This code was tested on DE2i FPGA board

/*Our team designed a cruise control system which allows the driver to activate
and controll the speed of the car without the accelerator or the brake. 
The system also maintains the speed of the car when the cars speed is equal
to the desired speed set by the driver. */




module Cruise_Control (
// INPUT FROM FPGA BOARD USING BUTTONS AND SWITCHES
input clk,
input accelerator,		// Simulates the gas pedel. Simulates w\ switch
input brake,			// Simulates brake pedel. Driver can controll car's speed with the accelerator and brake at any point. Simulates w\ switch
input cc, 				// Cruise control on/off (system on/off)
input add,				// +1 to desired speed. Simulates w\ a button
input subtract,			// -1 from desired speed. Simulates w\ a button
input too_close,		// Simulates a sensor on car that sends a HIGH signal when car is less than ten feet behind another car w\ a switch
input approaching_object,		// Simulates a sensor on car that sends a HIGH signal when car is approaching an obstacle too fast w\ a switch

// OUTPUT LED
output reg [5:0] ledtest,		// LEDs display the current state (see state transition block)
output reg [1:0] led,			// LEDr3 simulates alerting the driver that they are approaching an object. LEDg0 displays that cruise control is on

// OUTPUT 7 SEGMENT DISPLAY
output reg [0:6] seg1c,			// Current speed 10's place (current speed on left)
output reg [0:6] seg0c,			// Current speed 1's place
output reg [0:6] seg1d,			// Desired speed 10's place (desired speed on right)
output reg [0:6] seg0d			// Desired speed 1's place
);

// VARIABLES
reg [6:0] current_speed;
reg [6:0] desired_speed;
reg [3:0] cseg0;				// Current speed 10's digit
reg [3:0] dseg0;				// Desired speed 10's digit
integer cseg1;					// Current speed 1's digit (integer variable type rounds the number)
integer dseg1;					// Desired speed 1's digit (integer variable type rounds the number)

localparam OFF = 0, CC = 1, ACCELa = 2, DECEL = 3, ACCELb = 4, ALERT = 5;		//These are states for the program that are assigned a specific number to it
reg [2:0] current_state;
reg [2:0] next_state;

//new clock
reg [25:0] count = 0;
reg new_clk;
parameter max_count = 50000000/4;	//new clock cycle set to 2 per second

always @(posedge clk) begin
	if (count < max_count) begin
		count <= count + 1;
	end else begin
		count <= 0;					//reset count
		new_clk <= ~new_clk;		//reset clock
	end
end




//state transition
always @* begin																//driver is in control of speed
	next_state = current_state;
	case (current_state)							
		
		OFF: begin															//off is reset state. current speed will not reset.
			if (cc == 0) next_state = CC;												//CC button is pressed -> turn on CC			
		end
		
		//CC keeps the current speed constant. CC also acts like a central processing uint.
		CC: begin															//System is in control of speed (driver can immediately take control over the cars speed during any state)
			if (approaching_object == 1 & accelerator == 0) next_state = ALERT; ;		//Go to ALERT if the car is approaching the objetc in front too fast and the driver is not pressing the gas pedal (in case of false alerts)
			else if (too_close == 1) next_state = DECEL;								//Too close to the object in front -> go to DECEL (deceleration)
			else if (cc == 0) next_state = OFF;											//CC is turned off -> turn off CC
			else if (brake == 1) next_state = OFF;										//Brake pressed -> turn off CC
			else if (accelerator == 1) next_state = ACCELb;								//Gas pedal is pressed -> go to ACEELb (go pass limit of the CC)
			else if (current_speed > desired_speed) next_state = DECEL;					//Too fast -> slow down
			else if (current_speed < desired_speed) next_state = ACCELa;				//Too slow -> speed up
		end
		
		ACCELa: begin														//system is in control of speed
			if (approaching_object == 1) next_state = ALERT;							//Go to ALERT if the car is approaching the objetc in front too fast 
			else if (too_close == 1) next_state = DECEL;								//Too close to the object in front -> go to DECEL (deceleration)
			else if (cc == 0) next_state = OFF;											//CC is turned off -> turn off CC
			else if (brake == 1) next_state = OFF;										//Brake pressed -> turn off CC
			else if (accelerator == 1) next_state = ACCELb;								//Gas pedal is pressed -> go to ACEELb (go pass limit of the CC)
			else if (current_speed >= desired_speed) next_state = CC;					//Reached desired speed -> go to CC state 
		end
		
		DECEL: begin														//system is in control of speed
			if (approaching_object == 1) next_state = ALERT;							//Go to ALERT if the car is approaching the objetc in front too fast 
			else if (brake == 1) next_state = OFF;										//Brake pressed -> turn off CC
			else if (cc == 0) next_state = OFF;											//CC is turned off -> turn off CC
			else if (accelerator == 1) next_state = ACCELb;								//Gas pedal is pressed -> go to ACEELb (go pass limit of the CC)
			else if (too_close == 0 & current_speed < desired_speed) next_state = CC;	//No longer too close to the car in front and the current speed is less than the desired speed -> go to CC
			else if (current_speed == desired_speed) next_state = CC;					//current speed reaches desired speed -> go to CC
		end
		
		ACCELb: begin														//driver is in control of speed
			if (brake == 1) next_state = OFF;											//Brake pressed -> turn off CC
			else if (cc == 0) next_state = OFF;											//CC is switched off -> turn off CC
			else if (accelerator == 0) next_state = CC;									//Gas pedal is pressed -> go to ACEELb (go pass limit of the CC)
		end
		
		ALERT: begin														//system is in control of speed
			if (approaching_object == 0) next_state = CC;								//Go to CC if no longer approaching the object
			else if (brake == 1) next_state = OFF;										//Brake is pressed -> turn off CC
			else if (accelerator == 1) next_state = ACCELb;								//Gas pedal is pressed -> go to Accelb
		end
endcase
end


//current speed for each state. 
//Adds or subtracts desired speed and current speed according to states and inputs
//the car's hypothetical speed boundaries are 0mph - 64mph
always @(posedge new_clk) begin
		if (current_speed < 64 & add == 0) desired_speed = desired_speed + 1;			// Increment desired speed by 1 when ADD button is pressed		
		if (current_speed > 0 & subtract == 0) desired_speed = desired_speed - 1;		// Decrease  desired speed by 1 when SUBTRACT buttion is pressed
		if (desired_speed < 1) desired_speed = 0;										// Make sure desired speed cannot be set as a negative number
		if (desired_speed > 63) desired_speed = 64; ;									// Max desired speed is 64
		if (current_speed < 1) current_speed = 0;										// Lowest speed is 0
		if (current_speed > 63) current_speed = 64;										// Highest speed is 64

	current_state = next_state;
	case (current_state)

		//// Cruise Control is OFF, the speed is only dictated by gas pedel, brake pedal, and fiction
		OFF: begin																		
			if (current_speed < 64 & accelerator == 1) current_speed = current_speed + 1;				// Add 1 to current speed if gas pedel is pressed
			if (current_speed > 0 & brake == 1) current_speed = current_speed - 1;						// Subtract 1 from current speed if brake pedal is pressed
			if (current_speed > 0 & accelerator == 0 & brake == 0) current_speed = current_speed - 1;	// simulates car's natural deceleration due to friction when Cruise Control is off
			desired_speed = current_speed;																// make sure when Cruise Control is turned on, the desired speed is always equal to the current speed at frist.
		end

		//// Cruise Control is ON
		// In Cruise Control (maintaining speed)
		CC: begin
		end
		// Increase the current speed by 1 each clock cycle
		ACCELa: begin
			if (current_speed < 64)
			current_speed = current_speed + 1;
		end
		// Decrease the current speed by 1 each clock cycle
		DECEL: begin
			if (current_speed > 0)
			current_speed = current_speed - 1;	
		end
		// If gas pedel is pressed, add 1 to the current speed (used to go pass the limit set by the desired speed).
		ACCELb: begin
			if (current_speed < 64 & accelerator == 1)
			current_speed = current_speed + 1;
		end
		// If in ALERT state, decreases the current speed by 1
		ALERT: begin
			if (current_speed > 0)
			current_speed = current_speed - 1;
		end
	endcase
end




//output block. LED & 7-seg displays
always @* begin
	cseg1 = current_speed / 10;				//stores tens digit of current speed
	cseg0 = current_speed - cseg1 * 10;		//stores ones digit of current speed
	case (cseg1)
		0: seg1c = 7'b0000001;
		1: seg1c = 7'b1001111;
		2: seg1c = 7'b0010010;
		3: seg1c = 7'b0000110;
		4: seg1c = 7'b1001100;
		5: seg1c = 7'b0100100;
		6: seg1c = 7'b0100000;
		7: seg1c = 7'b0001111;
		8: seg1c = 7'b0000000;
		9: seg1c = 7'b0000100;
	endcase
	case (cseg0)
		0: seg0c = 7'b0000001;
		1: seg0c = 7'b1001111;
		2: seg0c = 7'b0010010;
		3: seg0c = 7'b0000110;
		4: seg0c = 7'b1001100;
		5: seg0c = 7'b0100100;
		6: seg0c = 7'b0100000;
		7: seg0c = 7'b0001111;
		8: seg0c = 7'b0000000;
		9: seg0c = 7'b0000100;
	endcase
	
	dseg1 = desired_speed / 10;
	dseg0 = desired_speed - dseg1 * 10;
	if(current_state == OFF) begin
		seg1d = 7'b1111111;
		seg0d = 7'b1111111;
	end
	else begin
	case (dseg1)
		0: seg1d = 7'b0000001;
		1: seg1d = 7'b1001111;
		2: seg1d = 7'b0010010;
		3: seg1d = 7'b0000110;
		4: seg1d = 7'b1001100;
		5: seg1d = 7'b0100100;
		6: seg1d = 7'b0100000;
		7: seg1d = 7'b0001111;
		8: seg1d = 7'b0000000;
		9: seg1d = 7'b0000100;
	endcase
	case (dseg0)
		0: seg0d = 7'b0000001;
		1: seg0d = 7'b1001111;
		2: seg0d = 7'b0010010;
		3: seg0d = 7'b0000110;
		4: seg0d = 7'b1001100;
		5: seg0d = 7'b0100100;
		6: seg0d = 7'b0100000;
		7: seg0d = 7'b0001111;
		8: seg0d = 7'b0000000;
		9: seg0d = 7'b0000100;
	endcase
	end
	case (current_state)
		OFF: begin 
			led = 2'b00;
			ledtest = 6'b000001;	//State: OFF
		end
		CC: begin
			led = 2'b01;			//CC on
			ledtest = 6'b000010;	//State: CC
		end
		ACCELa: begin
			led = 2'b01;
			ledtest = 6'b000100;	//State: ACCELa
		end
		DECEL: begin
			led = 2'b01;
			ledtest = 6'b001000;	//State: DECEL
		end
		ACCELb: begin
			led = 2'b00;
			ledtest = 6'b010000;	//State: ACCELb
		end
		ALERT: begin
			led = 2'b11;			//Alert on & CC on
			ledtest = 6'b100000;	//State: ALERT
		end
	endcase
end
endmodule