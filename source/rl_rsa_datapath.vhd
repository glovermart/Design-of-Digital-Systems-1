----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Abu Desalegn Tesema, Harish N. Venkata, Andrew G. Martey
-- 
-- Create Date: 10/20/2021 07:20:28 PM
-- Design Name: 
-- Module Name: rl_rsa_datapath - rl_behav_datapath
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

entity rl_rsa_datapath is
    generic (
		bit_width : natural := 256; --change it to 256
		M_BLOCK_SIZE: natural := 260 
	);
	Port (
	    clk 				: in  std_logic;
		reset_n 			: in  std_logic;
		--control
		opcode 			: in std_logic_vector(2 downto 0);
		
		--data
		data_a  		: in  std_logic_vector(bit_width-1 downto 0);
		data_b  		: in  std_logic_vector(bit_width-1 downto 0);
		data_c  		: in  std_logic_vector(bit_width-1 downto 0);
        data_c_1  		: in  std_logic_vector(M_BLOCK_SIZE-1 downto 0);		
		data_p_b  		: in  std_logic_vector(bit_width-1 downto 0);
		
		
		msg_out 		: out std_logic_vector(bit_width-1 downto 0);
		msg_out_pro: out std_logic_vector(M_BLOCK_SIZE-1 downto 0);
		key_bit_scan    : out std_logic;
		shift_b_mod    : out std_logic
	);
end rl_rsa_datapath;

architecture rl_behav_datapath of rl_rsa_datapath is
begin
	main_proc : process (opcode,data_a,data_b,data_c,data_c_1)
	begin

    case(opcode) is
    when "000" =>
	           msg_out <= data_a; 
    when "011" =>
	           msg_out_pro <=  data_c_1;   
	 when "001" =>
	           msg_out_pro <= std_logic_vector(unsigned (data_a)+unsigned (data_c_1));  
	 when "010" =>
	    if ((Unsigned(data_c_1) > Unsigned(data_b)) or (Unsigned(data_c_1) = Unsigned(data_b)))  then
			msg_out_pro <=std_logic_vector(unsigned (data_c_1)- unsigned (data_b));
		else
			msg_out_pro<=data_c_1;
		end if;
	   when "101"  =>
	         msg_out<= data_c_1 (255 downto 0);
	 when "110"=>
	           msg_out <= std_logic_vector(shift_left(unsigned(data_a),1));  
	 when "100"=>
	           msg_out_pro <= std_logic_vector(shift_left(unsigned(data_c_1),1));  
	when "111" =>
	           --key_bit_scan <= data_c(0);
	           msg_out <= std_logic_vector(shift_right(unsigned(data_a), 1 ));
	when others =>
	    msg_out <= (others=>'X');
	    end case;  
	   
	key_bit_scan <= data_c(0);
	shift_b_mod <= data_p_b(255);
	    
	end process main_proc;

end rl_behav_datapath;


