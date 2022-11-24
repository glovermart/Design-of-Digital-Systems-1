----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Abu Desalegn Tesema, Harish N. Venkata, Andrew G. Martey
-- 
-- Create Date: 10/20/2021 07:20:28 PM
-- Design Name: 
-- Module Name: rl_rsa_controller - rl_behav_controller
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rl_rsa_controller is
    generic (
		bit_width 			: positive := 256
	);
	port (
		--misc
		clk 				: in  std_logic;
		reset_n 			: in  std_logic;

		

		--external controll signals
		ready_in 			: out std_logic;
		valid_in 			: in  std_logic;

		ready_out 			: in  std_logic;
		valid_out 			: out std_logic;

		--internal controll signals
		read_a_select 		: out std_logic_vector(3 downto 0);
		read_b_select 		: out std_logic_vector(3 downto 0);
		read_c_select 		: out std_logic_vector(1 downto 0);
		write_select 		: out std_logic_vector(7 downto 0);
		opcode 				: out std_logic_vector(2 downto 0);
		
		-- Indicates boundary of last packet
		msgin_last             : in std_logic;
		msgout_last            : out std_logic;
		

		key_bit_scan   : in std_logic;
		shift_b_mod    : in std_logic
		
	);
end rl_rsa_controller;

architecture rl_behav_controller of rl_rsa_controller is
--for datapath opcodes
	constant datapath_load		      : std_logic_vector(2 downto 0) := "000";
	constant datapath_load_mod		  : std_logic_vector(2 downto 0) := "011";
	constant datapath_add		      : std_logic_vector(2 downto 0) := "001";
	constant datapath_sub		      : std_logic_vector(2 downto 0) := "010";
	constant datapath_pro		      : std_logic_vector(2 downto 0) := "101";
	constant datapath_shift_left	  : std_logic_vector(2 downto 0) := "110";
	constant datapath_shift_left_mod  : std_logic_vector(2 downto 0) := "100";
	constant datapath_shift_Right     : std_logic_vector(2 downto 0) := "111";
	constant datapath_copy_data       : std_logic_vector(2 downto 0) := "101";
	

	--for read sources
	constant read_reg_c		    : std_logic_vector(3 downto 0) := "0000";
	constant read_reg_p		    : std_logic_vector(3 downto 0) := "0001";
	constant read_reg_n		    : std_logic_vector(3 downto 0) := "0010";
	constant read_reg_k		    : std_logic_vector(3 downto 0) := "0011";
	constant read_input_m		: std_logic_vector(3 downto 0) := "0100";
	constant read_input_mod		: std_logic_vector(3 downto 0) := "0101";
	constant read_input_key		: std_logic_vector(3 downto 0) := "0110";
	constant reg_c_init 		: std_logic_vector(3 downto 0) := "0111";
	constant read_reg_c_a		: std_logic_vector(3 downto 0) := "1000";
	constant read_reg_p_b		: std_logic_vector(3 downto 0) := "1001";
	constant read_reg_modpro_p  : std_logic_vector(1 downto 0) := "10";
	constant reg_p_modpro_init 	: std_logic_vector(1 downto 0) := "11";

	--for write sources
	constant write_reg_c	    : std_logic_vector(7 downto 0) := "00000001";
	constant write_reg_p	    : std_logic_vector(7 downto 0) := "00000010";
	constant write_reg_n	    : std_logic_vector(7 downto 0) := "00000100";
	constant write_reg_k	    : std_logic_vector(7 downto 0) := "00001000";
	constant write_output	    : std_logic_vector(7 downto 0) := "00010000";
	constant write_reg_c_a	    : std_logic_vector(7 downto 0) := "00100000";
	constant write_reg_P_b	    : std_logic_vector(7 downto 0) := "01000000";
	constant write_reg_modpro_p	: std_logic_vector(7 downto 0) := "10000000";
	constant write_none 	    : std_logic_vector(7 downto 0) := "00000000";
	
	signal update_msg_count             : std_logic;

	type state_type_rl is (
	    --RL states
		reset      ,
		read_m     , --read input message
		init_reg_c , --initialize reg_c with '1'
		read_n     , --read the modulus
		read_key   , --read key, e or d
		cp         , --modural product
		reset_mod         , 
		mod_load_a,
		mod_load_b,
		shift_left_p  , --  p = 2p
		shift_b   , 
		mul_ab        , --  p = 2p + abj
		reduce_pn_1   , -- if p >= n then p = p - n
		reduce_pn_2   , -- if p >= n then p = p - n
		write_out_mod,
		shift_k    , --shift rigt key bit, e or d
		pp         , --modular product, squaring
		increment,
		cpo        , --modular product for MSB of key 
		write_out  , --write result to the output
		wait_out     --do nothing untill the result is recieved
	);
	signal state,state_next : state_type_rl;

	--counter for the for loop
	signal N 				: integer;

	--counter of modproduct
     signal N_mod : integer := 0;
     --for  controlling cp,pp,cpo states
     signal temp_var: integer :=0;

begin

	main_proc : process (state,valid_in,ready_out,key_bit_scan,shift_b_mod)
	--main_proc : process (state,valid_in,ready_out)
	begin
	
		opcode 			<= datapath_load;
		read_a_select 	<= read_reg_c;
		read_b_select 	<= read_reg_c;
		--read_c_select 	<= read_reg_c;
		ready_in 		<= '0';
		valid_out 		<= '0';
		state_next 		<= reset;
		write_select 	<= write_none;
		
		
		
		--main implementation of FSM
	
		case(state) is
			when reset =>
				read_a_select 	<= read_reg_c;
				read_b_select 	<= read_reg_c;
				write_select 	<= write_reg_c;
				opcode 			<= datapath_load;
                N<=0;
                N_mod<=0;
                temp_var<=0;
                ready_in 		<= '0';
                valid_out 		<= '0';
				state_next 		<= read_m;

			when read_m =>	
				if valid_in = '1' then
				    ready_in <= '1';
				    read_a_select <= read_input_m;
				    opcode <= datapath_load;
				    write_select <= write_reg_p;
					N<=0;
					state_next <= init_reg_c;
					update_msg_count <= '1';
				else	
					state_next <= read_m;
					update_msg_count <= '0';
				end if;
	
            when init_reg_c =>
				read_a_select <= reg_c_init;
				opcode <= datapath_load;
				write_select <= write_reg_c;
				state_next <= read_n;
				update_msg_count <= '0';

			when read_n =>
			--code can be minimized by shorting input data
				read_a_select <= read_input_mod;
				opcode <= datapath_load;
				write_select <= write_reg_n;
				state_next <= read_key;
				update_msg_count <= '0';
		    
		    when read_key =>
				read_a_select <= read_input_key;
				opcode <= datapath_load;
				write_select <= write_reg_k;
				update_msg_count <= '0';
				state_next <= cp;
			
			when cp =>
			    --read_c_select <= read_reg_k;
			    if ((key_bit_scan = '1') ) then
                   temp_var <=1;  
                   state_next <= reset_mod;            
			     else
			           state_next <= shift_k;
				end if;
				
			 when reset_mod => --reset
			     read_c_select <= reg_p_modpro_init;
			     opcode <= datapath_load_mod;
				 write_select <= write_reg_modpro_p;
				 N_mod<=0;
				 state_next<=mod_load_a;
				 
			when mod_load_a=>
				 if(temp_var = 1) then
				        read_a_select <= read_reg_c;
				        write_select <= write_reg_c_a;
				        opcode <= datapath_load;
				   elsif(temp_var = 2) then
				        read_a_select <= read_reg_p;
				        write_select <= write_reg_c_a;
				        opcode <= datapath_load;		    
				    else
				        read_a_select <= read_reg_c;
				        write_select <= write_reg_c_a;
				        opcode <= datapath_load;
				    end if;
				    state_next<=mod_load_b;
				     
				    when mod_load_b=>
				     if(temp_var = 1) then
				         read_a_select <= read_reg_p;
				         write_select <= write_reg_p_b;
				         opcode <= datapath_load;
				     elsif(temp_var = 2) then
				        read_a_select <= read_reg_p;
				        write_select <= write_reg_p_b;
				        opcode <= datapath_load;
				      else
				         read_a_select <= read_reg_p;
				         write_select <= write_reg_p_b;
				         opcode <= datapath_load;
				    end if;
				
				 state_next <= shift_left_p;
				 
           when shift_left_p => --p = 2p
                read_c_select <= read_reg_modpro_p;
				opcode <= datapath_shift_left_mod;
				write_select <= write_reg_modpro_p;   
                state_next <= mul_ab;
                --changed code here
--            when shift_b=>
--               read_a_select <= read_reg_p_b;
--				opcode <= datapath_shift_left;
--			    write_select <= write_reg_p_b;
--				state_next <= mul_ab;
           when mul_ab => --p = 2p + abj
                        if (shift_b_mod = '1') then
                            read_a_select <= read_reg_c_a;
                            read_c_select <= read_reg_modpro_p;
                            opcode <=datapath_add;
                            write_select <= write_reg_modpro_p;
                         
                        end if; 
                         state_next <= shift_b;
                         
                     when shift_b=>
                          read_a_select <= read_reg_p_b;
				          opcode <= datapath_shift_left;
			              write_select <= write_reg_p_b;
				          state_next <= reduce_pn_1;
                    when reduce_pn_1 => --p = p - n
                        read_c_select <= read_reg_modpro_p;
                        read_b_select <= read_reg_n;   
                        --if (input_greater = '1' or input_equal = '1') then
                           opcode <=datapath_sub;
                           write_select <= write_reg_modpro_p;                                 
                      -- end if ;
                        state_next <= reduce_pn_2;
                    when reduce_pn_2 => --p = p - n
                        read_c_select <= read_reg_modpro_p;
                        read_b_select <= read_reg_n;   
                      --  if (input_greater = '1' or input_equal = '1') then
                           opcode <=datapath_sub;
                           write_select <= write_reg_modpro_p; 
                     --   end if;
                       if N_mod = 255 then
                           state_next <= write_out_mod;
                       else
                           state_next <= shift_left_p;
                           N_mod <= N_mod+1;
                       end if;
                    when write_out_mod => --return value
                        
                       if(temp_var = 1) then
                            read_c_select <= read_reg_modpro_p;
                            opcode <= datapath_copy_data;
                             write_select <= write_reg_c;
                             state_next <= shift_k;
                       elsif (temp_var = 2) then
                            read_c_select <= read_reg_modpro_p;
                            opcode <= datapath_copy_data;
                             write_select <= write_reg_p;
                            state_next<= increment;
                       else
                            read_c_select <= read_reg_modpro_p;
                            opcode <= datapath_copy_data;
                             write_select <= write_reg_c;
                            state_next <= write_out;
                       end if;
			when shift_k =>
				read_a_select <= read_reg_k;
				opcode <= datapath_shift_right;
				write_select <= write_reg_k;
				state_next <= pp;
			
			when pp =>
       --the operation should be replaced with mod product(squaring)
				temp_var <=2;
			    state_next<=reset_mod;
			    
			when increment =>
			 if N = 254 then
					state_next <= cpo;					
				else
					N<=N+1;
					state_next <= cp;
				end if;	
			when cpo =>
			    if key_bit_scan = '1' then
                  temp_var<=3;
                  state_next <= reset_mod;
                  else
                        state_next <= write_out;
				end if;	
			when write_out =>
				read_a_select <= read_reg_c;
				opcode <= datapath_load;
				write_select <= write_output;
				update_msg_count <= '0';
				state_next <= wait_out;
			    
			when wait_out =>
				if ready_out = '1' then
				    valid_out <= '1';
					state_next <= reset;
				else
					state_next <= wait_out;
				end if;
			when others =>
				read_a_select 	<= read_reg_c;
				read_b_select 	<= read_reg_c;
				read_c_select 	<= reg_p_modpro_init;
				write_select 	<= write_none;
				valid_out 		<= '0';
				ready_in 		<= '0';
				opcode 			<= datapath_load;
				state_next 		<= reset;
		end case;
	end process main_proc;

	update_state : process (reset_n, clk)
	begin
		if (reset_n = '0') then
			state <= reset;
		elsif (rising_edge(clk)) then
		    
			state <= state_next;
		end if;
		
		 if (update_msg_count = '1') then
                msgout_last <= msgin_last;
            end if;
		
	end process update_state;

end rl_behav_controller;
