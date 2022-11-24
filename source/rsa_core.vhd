--------------------------------------------------------------------------------
-- Author       : Oystein Gjermundnes
--				  Abu Desalegn Tesema, Harish N. Venkata, Andrew G. Martey
-- Organization : Norwegian University of Science and Technology (NTNU)
--                Department of Electronic Systems
--                https://www.ntnu.edu/ies
-- Course       : TFE4141 Design of digital systems 1 (DDS1)
-- Year         : 2018-2019
-- Project      : RSA accelerator
-- License      : This is free and unencumbered software released into the
--                public domain (UNLICENSE)
--------------------------------------------------------------------------------
-- Purpose:
--   RSA encryption core template. This core currently computes
--   C = M xor key_n
--
--   Replace/change this module so that it implements the function
--   C = M**key_e mod key_n.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity rsa_core is
	generic (
		-- Users to add parameters here
		C_BLOCK_SIZE          : integer := 256;
		M_BLOCK_SIZE          : integer := 260
	);
	port (
		-----------------------------------------------------------------------------
		-- Clocks and reset
		-----------------------------------------------------------------------------
		clk                    :  in std_logic;
		reset_n                :  in std_logic;

		-----------------------------------------------------------------------------
		-- Slave msgin interface
		-----------------------------------------------------------------------------
		-- Message that will be sent out is valid
		msgin_valid             : in std_logic;
		-- Slave ready to accept a new message
		msgin_ready             : out std_logic;
		-- Message that will be sent out of the rsa_msgin module
		msgin_data              :  in std_logic_vector(C_BLOCK_SIZE-1 downto 0);
		-- Indicates boundary of last packet
		msgin_last              :  in std_logic;

		-----------------------------------------------------------------------------
		-- Master msgout interface
		-----------------------------------------------------------------------------
		-- Message that will be sent out is valid
		msgout_valid            : out std_logic;
		-- Slave ready to accept a new message
		msgout_ready            :  in std_logic;
		-- Message that will be sent out of the rsa_msgin module
		msgout_data             : out std_logic_vector(C_BLOCK_SIZE-1 downto 0);
		
		-- Indicates boundary of last packet
		msgout_last             : out std_logic;

		-----------------------------------------------------------------------------
		-- Interface to the register block
		-----------------------------------------------------------------------------
		key_e_d                 :  in std_logic_vector(C_BLOCK_SIZE-1 downto 0);
		key_n                   :  in std_logic_vector(C_BLOCK_SIZE-1 downto 0);
		rsa_status              : out std_logic_vector(31 downto 0)

	);
end rsa_core;

architecture rtl of rsa_core is

	--signals for communicating between controller and datapath
    signal read_c_select 	: std_logic_vector(1 downto 0);
	signal read_b_select 	: std_logic_vector(3 downto 0);
	signal read_a_select 	: std_logic_vector(3 downto 0);
	signal write_select 	: std_logic_vector(7 downto 0);
	signal opcode 			: std_logic_vector(2 downto 0);
	signal key_bit_scan	    : std_logic;
 

	--registers for data storage
	signal reg_c 			: std_logic_vector(C_BLOCK_SIZE-1 downto 0);
	signal reg_p 			: std_logic_vector(C_BLOCK_SIZE-1 downto 0);
	signal reg_n 			: std_logic_vector(C_BLOCK_SIZE-1 downto 0);
	signal reg_k 			: std_logic_vector(C_BLOCK_SIZE-1 downto 0);
	
	signal reg_c_a 			: std_logic_vector(C_BLOCK_SIZE-1 downto 0);
	signal reg_p_b 			: std_logic_vector(C_BLOCK_SIZE-1 downto 0);
	signal reg_modpro_p 			: std_logic_vector(M_BLOCK_SIZE-1 downto 0);

    signal shift_b_mod    : std_logic;
	--wires in and out for the datapath
	signal datapath_output 		: std_logic_vector(C_BLOCK_SIZE-1 downto 0);
	signal datapath_output_pro 		: std_logic_vector(M_BLOCK_SIZE-1 downto 0);
	signal bus_a 			: std_logic_vector(C_BLOCK_SIZE-1 downto 0);
	signal bus_b 			: std_logic_vector(C_BLOCK_SIZE-1 downto 0);
	signal bus_c 			: std_logic_vector(M_BLOCK_SIZE-1 downto 0);
	
	signal modulos_n 			: std_logic_vector(C_BLOCK_SIZE-1 downto 0);
	
	signal reg_c_init       : std_logic_vector(C_BLOCK_SIZE-1 downto 0) := x"0000000000000000000000000000000000000000000000000000000000000001"; --change it to 256 format
    signal reg_p_modpro_init:  std_logic_vector(260-1 downto 0):= x"00000000000000000000000000000000000000000000000000000000000000000";
begin
	

	--instantiate the controller and connect it to the required components
	i_controller : entity work.rl_rsa_controller(rl_behav_controller)
		generic map (
			bit_width => C_BLOCK_SIZE
		)
		port map (
			clk           	=> clk           ,
			reset_n       	=> reset_n       ,
			ready_in      	=> msgin_ready      ,
			valid_in      	=> msgin_valid      ,
			ready_out     	=> msgout_ready     ,
			valid_out     	=> msgout_valid    ,
			read_a_select   => read_a_select ,
			read_b_select   => read_b_select ,
			read_c_select   => read_c_select ,
			write_select  	=> write_select  ,
			opcode        	=> opcode        ,
			msgin_last  => msgin_last,
			msgout_last  => msgout_last,
			shift_b_mod        	=> shift_b_mod         ,
			key_bit_scan    => key_bit_scan
		);

	
	--read_proc : process (read_a_select,read_b_select,msgin_data,reg_c,reg_p,reg_n,reg_k,key_n,key_e_d,reg_c_init,reg_c_a,reg_p_b,reg_modpro_p)
	read_proc : process (read_a_select,read_b_select,read_c_select,msgin_data,reg_c,reg_p,reg_n,reg_k,key_n,key_e_d,reg_c_init,reg_c_a,reg_p_b,reg_modpro_p)
	begin
		MUX_A : case(read_a_select) is
			when "0000" =>	bus_a <= reg_c;
			when "0001" =>	bus_a <= reg_p;
			when "0010" =>	bus_a <= reg_n;
			when "0011" =>	bus_a <= reg_k;
			when "0100" =>	bus_a <= msgin_data;
			when "0101" =>	bus_a <= key_n;
			when "0110" =>	bus_a <= key_e_d;
			when "0111" =>	bus_a <= reg_c_init;
			when "1000" =>	bus_a <= reg_c_a;
			when "1001" =>	bus_a <= reg_p_b;
			when others =>	bus_a <= (others=>'0');
		end case MUX_A;
		MUX_B : case(read_b_select) is
			when "0000" =>	bus_b <= reg_c;
			when "0001" =>	bus_b <= reg_p;
			when "0010" =>	bus_b <= reg_n;
			when "0011" =>	bus_b <= reg_k;
			when "0100" =>	bus_b <= msgin_data;
			when "0101" =>	bus_b <= key_n;
			when "0110" =>	bus_b <= key_e_d;
			when "0111" =>	bus_b <= reg_c_init;
			when "1000" =>	bus_b <= reg_c_a;
			when "1001" =>	bus_b <= reg_p_b;
			when others =>	bus_b <= (others=>'0');
		end case MUX_B;
		MUX_C : case(read_c_select) is
			when "10" =>	bus_c <= reg_modpro_p;
			when "11" =>	bus_c <= reg_p_modpro_init;
			
			when others =>	bus_c <= (others=>'0');
		end case MUX_C;
	end process read_proc;


	i_datapath : entity work.rl_rsa_datapath(rl_behav_datapath)
		generic map (
			bit_width => C_BLOCK_SIZE
		)
		port map (
		    clk           	=> clk           ,
			reset_n       	=> reset_n       ,
			opcode        => opcode        ,
			data_a        => bus_a         ,
			data_b        => bus_b         ,
			data_c        => reg_k         ,
			data_c_1  => bus_c,
			msg_out      => datapath_output    ,
			msg_out_pro      => datapath_output_pro    ,
			key_bit_scan    => key_bit_scan,
			shift_b_mod        	=> shift_b_mod         ,
			data_p_b => reg_p_b
		);



	--write_proc : process (reset_n, clk,datapath_output)
	write_proc : process (reset_n, clk,datapath_output)
	begin
		if (reset_n = '0') then
			--resetting all registers
			reg_c <= (others=>'0');
			reg_p <= (others=>'0');
			reg_n <= (others=>'0');
			reg_k <= (others=>'0');
			reg_c_a <= (others=>'0');
			reg_p_b <= (others=>'0');
			reg_modpro_p<= (others=>'0');
			msgout_data <= (others=>'0');
		elsif (rising_edge(clk)) then
			
			if write_select(0) = '1' then
				reg_c <= datapath_output;
			end if ;

			if write_select(1) = '1' then
				reg_p <= datapath_output;
			end if ;

			if write_select(2) = '1' then
				reg_n <= datapath_output;
			end if ;

			if write_select(3) = '1' then
				reg_k <= datapath_output;
			end if ;

			if write_select(4) = '1' then
				msgout_data <= datapath_output;
			end if ;
			
			if write_select(5) = '1' then
				reg_c_a <= datapath_output;
			end if ;

			if write_select(6) = '1' then
				reg_p_b <= datapath_output;
			end if ;
			
			if write_select(7) = '1' then
				reg_modpro_p <= datapath_output_pro;
			end if ;

		end if;
	end process write_proc;

	--msgout_last  <= msgin_last;
	rsa_status   <= (others => '0');
end rtl;
