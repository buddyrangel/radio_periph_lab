library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity full_radio_v1_0 is
	generic (
		-- Users to add parameters here

		-- User parameters ends
		-- Do not modify the parameters beyond this line


		-- Parameters of Axi Slave Bus Interface S00_AXI
		C_S00_AXI_DATA_WIDTH	: integer	:= 32;
		C_S00_AXI_ADDR_WIDTH	: integer	:= 4
	);
	port (
		-- Users to add ports here
        m_axis_tvalid : out std_logic;
        m_axis_tdata : out std_logic_vector(31 downto 0);
		-- User ports ends
		-- Do not modify the ports beyond this line


		-- Ports of Axi Slave Bus Interface S00_AXI
		s00_axi_aclk	: in std_logic;
		s00_axi_aresetn	: in std_logic;
		s00_axi_awaddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_awprot	: in std_logic_vector(2 downto 0);
		s00_axi_awvalid	: in std_logic;
		s00_axi_awready	: out std_logic;
		s00_axi_wdata	: in std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_wstrb	: in std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
		s00_axi_wvalid	: in std_logic;
		s00_axi_wready	: out std_logic;
		s00_axi_bresp	: out std_logic_vector(1 downto 0);
		s00_axi_bvalid	: out std_logic;
		s00_axi_bready	: in std_logic;
		s00_axi_araddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_arprot	: in std_logic_vector(2 downto 0);
		s00_axi_arvalid	: in std_logic;
		s00_axi_arready	: out std_logic;
		s00_axi_rdata	: out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_rresp	: out std_logic_vector(1 downto 0);
		s00_axi_rvalid	: out std_logic;
		s00_axi_rready	: in std_logic
	);
end full_radio_v1_0;

architecture arch_imp of full_radio_v1_0 is

	-- component declaration
	component full_radio_v1_0_S00_AXI is
		generic (
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		C_S_AXI_ADDR_WIDTH	: integer	:= 4
		);
		port (
		m_axis_tvalid : out std_logic;
		m_axis_tdata : out std_logic_Vector(31 downto 0);

   		 --//////////////////////////////////////////////////////////////
		 -- Lab 10 Modification: Radio DSP Control Ports
    		 -- Purpose: Declare the AXI-Lite control outputs used
   		 --          	     the radio processing module.
   		 --//////////////////////////////////////////////////////////////

    		 fake_adc_phase_inc : out std_logic_vector(31 downto 0);
		 tuner_phase_inc    : out std_logic_vector(31 downto 0);
		 dds_resetn_out     : out std_logic;
		 tuner_config_valid : out std_logic;

		S_AXI_ACLK	: in std_logic;
		S_AXI_ARESETN	: in std_logic;
		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
		S_AXI_AWVALID	: in std_logic;
		S_AXI_AWREADY	: out std_logic;
		S_AXI_WDATA	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		S_AXI_WVALID	: in std_logic;
		S_AXI_WREADY	: out std_logic;
		S_AXI_BRESP	: out std_logic_vector(1 downto 0);
		S_AXI_BVALID	: out std_logic;
		S_AXI_BREADY	: in std_logic;
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
		S_AXI_ARVALID	: in std_logic;
		S_AXI_ARREADY	: out std_logic;
		S_AXI_RDATA	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP	: out std_logic_vector(1 downto 0);
		S_AXI_RVALID	: out std_logic;
		S_AXI_RREADY	: in std_logic
		);
	end component full_radio_v1_0_S00_AXI;

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: Radio DSP Component Declaration
    -- Purpose: Declare the complete digital downconverter
    --          	containing the fake ADC DDS, tuner DDS,
    --          	complex mixer, FIR filters, and stereo output.
    --//////////////////////////////////////////////////////////////

    component radio_dsp is
        port (
            clk125             : in  std_logic;
            resetn             : in  std_logic;

            fake_adc_phase_inc : in  std_logic_vector(31 downto 0);
            tuner_phase_inc    : in  std_logic_vector(31 downto 0);

            dds_resetn         : in  std_logic;
            tuner_config_valid : in  std_logic;

            m_axis_tdata       : out std_logic_vector(31 downto 0);
            m_axis_tvalid      : out std_logic
        );
    end component;

		--//////////////////////////////////////////////////////////////
		-- Lab 10 Modification: Radio DSP Control Signals
		-- Purpose: Carry the AXI-Lite register values and tuner
		--                 configuration pulse to the radio DSP module.
		--//////////////////////////////////////////////////////////////

		signal radio_fake_adc_phase_inc : std_logic_vector(31 downto 0);
		signal radio_tuner_phase_inc    : std_logic_vector(31 downto 0);
		signal radio_dds_resetn         : std_logic;
		signal radio_tuner_config_valid : std_logic;

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: Radio DSP Audio Output Signals
    -- Purpose: Carry the completed stereo audio stream from
    --          the DSP module to the peripheral interface.
    --//////////////////////////////////////////////////////////////

    signal radio_audio_tdata  : std_logic_vector(31 downto 0);
    signal radio_audio_tvalid : std_logic;

begin

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: DSP AXI-Stream Output Connections
    -- Purpose: Route the completed stereo audio stream from
    --          the radio DSP module to the peripheral outputs.
    --//////////////////////////////////////////////////////////////

    m_axis_tdata  <= radio_audio_tdata;
    m_axis_tvalid <= radio_audio_tvalid;

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: Radio DSP Instantiation
    -- Purpose: Connect the AXI-Lite control registers to
    --          the complete digital downconverter and capture
    --          its stereo AXI-Stream audio outputs.
    --//////////////////////////////////////////////////////////////

    radio_dsp_inst : radio_dsp
        port map (
            clk125             => s00_axi_aclk,
            resetn             => s00_axi_aresetn,

            fake_adc_phase_inc => radio_fake_adc_phase_inc,
            tuner_phase_inc    => radio_tuner_phase_inc,

            dds_resetn         => radio_dds_resetn,
            tuner_config_valid => radio_tuner_config_valid,

            m_axis_tdata       => radio_audio_tdata,
            m_axis_tvalid      => radio_audio_tvalid
        );

-- Instantiation of Axi Bus Interface S00_AXI
full_radio_v1_0_S00_AXI_inst : full_radio_v1_0_S00_AXI
	generic map (
		C_S_AXI_DATA_WIDTH	=> C_S00_AXI_DATA_WIDTH,
		C_S_AXI_ADDR_WIDTH	=> C_S00_AXI_ADDR_WIDTH
	)
	port map (
    		--//////////////////////////////////////////////////////////////
    		-- Lab 10 Modification: Disconnect Original DDS Audio Stream
    		-- Purpose: Release the top-level AXI-Stream outputs so
    		--          the radio DSP module can drive stereo audio.
    		--//////////////////////////////////////////////////////////////

    		-- Original professor connections:
    		-- m_axis_tdata  => m_axis_tdata,
    		-- m_axis_tvalid => m_axis_tvalid,

    		m_axis_tdata  => open,
    		m_axis_tvalid => open,

   		 --//////////////////////////////////////////////////////////////
   		 -- Lab 10 Modification: Radio DSP Control Connections
   		 -- Purpose: Route the AXI-Lite register outputs and tuner
   		 --          configuration pulse to the top-level signals.
		 --//////////////////////////////////////////////////////////////

   		 fake_adc_phase_inc => radio_fake_adc_phase_inc,
   		 tuner_phase_inc    => radio_tuner_phase_inc,
   		 dds_resetn_out     => radio_dds_resetn,
		 tuner_config_valid => radio_tuner_config_valid,

		S_AXI_ACLK	=> s00_axi_aclk,
		S_AXI_ARESETN	=> s00_axi_aresetn,
		S_AXI_AWADDR	=> s00_axi_awaddr,
		S_AXI_AWPROT	=> s00_axi_awprot,
		S_AXI_AWVALID	=> s00_axi_awvalid,
		S_AXI_AWREADY	=> s00_axi_awready,
		S_AXI_WDATA	=> s00_axi_wdata,
		S_AXI_WSTRB	=> s00_axi_wstrb,
		S_AXI_WVALID	=> s00_axi_wvalid,
		S_AXI_WREADY	=> s00_axi_wready,
		S_AXI_BRESP	=> s00_axi_bresp,
		S_AXI_BVALID	=> s00_axi_bvalid,
		S_AXI_BREADY	=> s00_axi_bready,
		S_AXI_ARADDR	=> s00_axi_araddr,
		S_AXI_ARPROT	=> s00_axi_arprot,
		S_AXI_ARVALID	=> s00_axi_arvalid,
		S_AXI_ARREADY	=> s00_axi_arready,
		S_AXI_RDATA	=> s00_axi_rdata,
		S_AXI_RRESP	=> s00_axi_rresp,
		S_AXI_RVALID	=> s00_axi_rvalid,
		S_AXI_RREADY	=> s00_axi_rready
	);

	-- Add user logic here



	-- User logic ends

end arch_imp;
