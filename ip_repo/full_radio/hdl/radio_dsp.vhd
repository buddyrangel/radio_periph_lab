library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--//////////////////////////////////////////////////////////////
-- Lab 10: Radio Digital Signal Processing Module
-- Purpose: Implement the digital downconverter using the
--                 fake ADC DDS, tuner DDS, complex I/Q mixer,
--          	    FIR filters, and AXI-Stream audio output.
--//////////////////////////////////////////////////////////////

entity radio_dsp is
    port (

        -- Clock and system reset
        clk125 : in std_logic;
        resetn : in std_logic;

        -- AXI-Lite radio control signals
        fake_adc_phase_inc : in std_logic_vector(31 downto 0);
        tuner_phase_inc    : in std_logic_vector(31 downto 0);
        dds_resetn         : in std_logic;
        tuner_config_valid : in std_logic;

        -- AXI-Stream audio output
        m_axis_tdata  : out std_logic_vector(31 downto 0);
        m_axis_tvalid : out std_logic

    );
end radio_dsp;

architecture rtl of radio_dsp is

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: Fake ADC DDS Component
    -- Purpose: Declare the professor-provided DDS Compiler
    --          	used to generate the simulated ADC input.
    --//////////////////////////////////////////////////////////////

    component dds_compiler_0 is
        port (
            aclk                 : in  std_logic;
            aresetn              : in  std_logic;
            s_axis_phase_tvalid  : in  std_logic;
            s_axis_phase_tdata   : in  std_logic_vector(31 downto 0);
            m_axis_data_tvalid   : out std_logic;
            m_axis_data_tdata    : out std_logic_vector(31 downto 0)
        );
    end component;

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: Tuner DDS Component
    -- Purpose: Declare the Lab 8 tuner DDS Compiler used
    --          	to generate the complex mixing signals.
    --//////////////////////////////////////////////////////////////

    component tuner_dds is
        port (
            aclk                 : in  std_logic;
            s_axis_config_tvalid : in  std_logic;
            s_axis_config_tdata  : in  std_logic_vector(31 downto 0);
            m_axis_data_tvalid   : out std_logic;
            m_axis_data_tdata    : out std_logic_vector(31 downto 0)
        );
    end component;

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: FIR Filter 1 Component
    -- Purpose: Declare the first-stage FIR decimation filter
    --          	from Lab 8. The filter decimates by 40 and
    --          	processes 16-bit signed input samples.
    --//////////////////////////////////////////////////////////////

    component fir_filter1 is
        port (
            aclk                : in  std_logic;
            aresetn             : in  std_logic;

            s_axis_data_tvalid  : in  std_logic;
            s_axis_data_tready  : out std_logic;
            s_axis_data_tdata   : in  std_logic_vector(15 downto 0);

            m_axis_data_tvalid  : out std_logic;
            m_axis_data_tdata   : out std_logic_vector(39 downto 0)
        );
    end component;

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: FIR Filter 2 Component
    -- Purpose: Declare the second-stage FIR decimation filter
    --          	from Lab 8. The filter decimates by 64 and
    --          	processes 16-bit signed input samples.
    --//////////////////////////////////////////////////////////////

    component fir_filter2 is
        port (
            aclk                : in  std_logic;
            aresetn             : in  std_logic;

            s_axis_data_tvalid  : in  std_logic;
            s_axis_data_tready  : out std_logic;
            s_axis_data_tdata   : in  std_logic_vector(15 downto 0);

            m_axis_data_tvalid  : out std_logic;
            m_axis_data_tdata   : out std_logic_vector(39 downto 0)
        );
    end component;

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: Fake ADC DDS Signals
    -- Purpose: Store the DDS output samples and data-valid
    --          	indication for subsequent mixer processing.
    --//////////////////////////////////////////////////////////////

    signal fake_adc_data  : std_logic_vector(31 downto 0);
    signal fake_adc_valid : std_logic;

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: Tuner DDS Signals
    -- Purpose: Store the tuner DDS sine/cosine output and
    --          	data-valid indication for complex I/Q mixing.
    --//////////////////////////////////////////////////////////////

    signal tuner_data  : std_logic_vector(31 downto 0);
    signal tuner_valid : std_logic;

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: Complex I/Q Mixer Signals
    -- Purpose: Prepare the fake ADC sample and tuner sine/
    --          	cosine signals for complex downconversion.
    --//////////////////////////////////////////////////////////////

    signal fake_adc_sample : signed(15 downto 0);

    signal tuner_sine      : signed(14 downto 0);
    signal tuner_cosine    : signed(14 downto 0);

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: Mixer Product Signals
    -- Purpose: Store the full-precision multiplication
    --          	results before scaling and saturation.
    --//////////////////////////////////////////////////////////////

    signal mixer_i_product : signed(30 downto 0);
    signal mixer_q_product : signed(30 downto 0);

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: Mixer Output Signals
    -- Purpose: Provide 16-bit signed I/Q samples and a
    --          	valid indication to the FIR filter chain.
    --//////////////////////////////////////////////////////////////

    signal mixer_i_data : signed(15 downto 0);
    signal mixer_q_data : signed(15 downto 0);
    signal mixer_valid  : std_logic;

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: FIR Filter 1 Channel Signals
    -- Purpose: Provide independent I/Q channel connections
    --          	for the first-stage FIR decimation filters.
    --//////////////////////////////////////////////////////////////

    -- FIR1 input ready signals
    signal fir1_i_ready : std_logic;
    signal fir1_q_ready : std_logic;

    -- FIR1 output valid signals
    signal fir1_i_valid : std_logic;
    signal fir1_q_valid : std_logic;

    -- FIR1 full-precision output samples
    signal fir1_i_data : std_logic_vector(39 downto 0);
    signal fir1_q_data : std_logic_vector(39 downto 0);

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: FIR1 Output Scaling Signals
    -- Purpose: Store the 16-bit signed I/Q samples after
    --          	scaling and saturating the 40-bit FIR1 outputs.
    --          	These samples will feed the FIR2 filters.
    --//////////////////////////////////////////////////////////////

    signal fir1_i_scaled : signed(15 downto 0);
    signal fir1_q_scaled : signed(15 downto 0);

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: FIR Filter 2 Channel Signals
    -- Purpose: Provide independent I/Q channel connections
    --          	for the second-stage FIR decimation filters.
    --//////////////////////////////////////////////////////////////

    -- FIR2 input ready signals
    signal fir2_i_ready : std_logic;
    signal fir2_q_ready : std_logic;

    -- FIR2 output valid signals
    signal fir2_i_valid : std_logic;
    signal fir2_q_valid : std_logic;

    -- FIR2 full-precision output samples
    signal fir2_i_data : std_logic_vector(39 downto 0);
    signal fir2_q_data : std_logic_vector(39 downto 0);

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: FIR2 Output Scaling Signals
    -- Purpose: Store the final 16-bit signed I/Q audio samples
    --          	after scaling and saturating the FIR2 outputs.
    --          	These samples will feed the AXI-Stream interface.
    --//////////////////////////////////////////////////////////////

    signal audio_i_sample : signed(15 downto 0);
    signal audio_q_sample : signed(15 downto 0);

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: Stereo AXI-Stream Audio Signals
    -- Purpose: Combine the final 16-bit I/Q audio samples
    --          into a 32-bit stereo audio word and indicate
    --          when a new audio sample pair is valid.
    --//////////////////////////////////////////////////////////////

    signal stereo_audio_data  : std_logic_vector(31 downto 0);
    signal stereo_audio_valid : std_logic;

begin

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: Fake ADC DDS Instantiation
    -- Purpose: Generate the simulated ADC signal using the
    --          	phase increment programmed through AXI-Lite.
    --//////////////////////////////////////////////////////////////

    fake_adc_dds_inst : dds_compiler_0
        port map (
            aclk                => clk125,
            aresetn             => dds_resetn,
            s_axis_phase_tvalid => '1',
            s_axis_phase_tdata  => fake_adc_phase_inc,
            m_axis_data_tvalid  => fake_adc_valid,
            m_axis_data_tdata   => fake_adc_data
        );

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: Tuner DDS Instantiation
    -- Purpose: Generate the programmable sine and cosine
    --          	signals used for complex I/Q mixing.
    --//////////////////////////////////////////////////////////////

    tuner_dds_inst : tuner_dds
        port map (
            aclk                 => clk125,
            s_axis_config_tvalid => tuner_config_valid,
            s_axis_config_tdata  => tuner_phase_inc,
            m_axis_data_tvalid   => tuner_valid,
            m_axis_data_tdata    => tuner_data
        );

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: DDS Sample Extraction
    -- Purpose: Extract the signed fake ADC sample and the
    --          	tuner sine/cosine samples for I/Q mixing.
    --//////////////////////////////////////////////////////////////

    fake_adc_sample <= signed(fake_adc_data(31 downto 16));

    tuner_sine   <= signed(tuner_data(30 downto 16));
    tuner_cosine <= signed(tuner_data(14 downto 0));

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: Complex I/Q Mixer
    -- Purpose: Multiply the fake ADC sample by the tuner
    --          	cosine and negative sine to generate the
    --          	in-phase (I) and quadrature (Q) components.
    --//////////////////////////////////////////////////////////////

    process (clk125)
    begin
        if rising_edge(clk125) then

            if dds_resetn = '0' then

                mixer_i_product <= (others => '0');
                mixer_q_product <= (others => '0');
                mixer_valid     <= '0';

            else

                mixer_valid <= '0';

                if fake_adc_valid = '1' and tuner_valid = '1' then

                    mixer_i_product <= fake_adc_sample * tuner_cosine;
                    mixer_q_product <= -(fake_adc_sample * tuner_sine);

                    mixer_valid <= '1';

                end if;

            end if;

        end if;
    end process;

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: Mixer Output Scaling and Saturation
    -- Purpose: Convert the 31-bit signed I/Q products into
    --          	16-bit signed samples for the FIR filter chain.
    --          	Apply arithmetic right shift by 14 bits and
    --          	saturate to prevent signed overflow.
    --//////////////////////////////////////////////////////////////

    process (mixer_i_product, mixer_q_product)

        variable i_scaled : signed(30 downto 0);
        variable q_scaled : signed(30 downto 0);

    begin

        -- Scale the full-precision mixer products
        i_scaled := shift_right(mixer_i_product, 14);
        q_scaled := shift_right(mixer_q_product, 14);

        --//////////////////////////////////////////////////////////
        -- In-Phase (I) Saturation
        --//////////////////////////////////////////////////////////

        if i_scaled > to_signed(32767, 31) then

            mixer_i_data <= to_signed(32767, 16);

        elsif i_scaled < to_signed(-32768, 31) then

            mixer_i_data <= to_signed(-32768, 16);

        else

            mixer_i_data <= resize(i_scaled, 16);

        end if;

        --//////////////////////////////////////////////////////////
        -- Quadrature (Q) Saturation
        --//////////////////////////////////////////////////////////

        if q_scaled > to_signed(32767, 31) then

            mixer_q_data <= to_signed(32767, 16);

        elsif q_scaled < to_signed(-32768, 31) then

            mixer_q_data <= to_signed(-32768, 16);

        else

            mixer_q_data <= resize(q_scaled, 16);

        end if;

    end process;

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: FIR1 In-Phase Channel
    -- Purpose: Filter and decimate the 16-bit I-channel
    --          	mixer samples by a factor of 40.
    --//////////////////////////////////////////////////////////////

    fir1_i_inst : fir_filter1
        port map (
            aclk               => clk125,
            aresetn            => dds_resetn,

            s_axis_data_tvalid => mixer_valid,
            s_axis_data_tready => fir1_i_ready,
            s_axis_data_tdata  => std_logic_vector(mixer_i_data),

            m_axis_data_tvalid => fir1_i_valid,
            m_axis_data_tdata  => fir1_i_data
        );

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: FIR1 Quadrature Channel
    -- Purpose: Filter and decimate the 16-bit Q-channel
    --          	mixer samples by a factor of 40.
    --//////////////////////////////////////////////////////////////

    fir1_q_inst : fir_filter1
        port map (
            aclk               => clk125,
            aresetn            => dds_resetn,

            s_axis_data_tvalid => mixer_valid,
            s_axis_data_tready => fir1_q_ready,
            s_axis_data_tdata  => std_logic_vector(mixer_q_data),

            m_axis_data_tvalid => fir1_q_valid,
            m_axis_data_tdata  => fir1_q_data
        );

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: FIR1 Output Scaling and Saturation
    -- Purpose: Convert the 40-bit signed FIR1 I/Q outputs
    --          	into 16-bit signed samples for FIR2.
    --          	Apply arithmetic right shift by 23 bits and
    --          	saturate to prevent signed overflow.
    --//////////////////////////////////////////////////////////////

    process (fir1_i_data, fir1_q_data)

        variable i_scaled : signed(39 downto 0);
        variable q_scaled : signed(39 downto 0);

    begin

        -- Scale the full-precision FIR1 outputs
        i_scaled := shift_right(signed(fir1_i_data), 23);
        q_scaled := shift_right(signed(fir1_q_data), 23);

        --//////////////////////////////////////////////////////////
        -- FIR1 In-Phase (I) Saturation
        --//////////////////////////////////////////////////////////

        if i_scaled > to_signed(32767, 40) then

            fir1_i_scaled <= to_signed(32767, 16);

        elsif i_scaled < to_signed(-32768, 40) then

            fir1_i_scaled <= to_signed(-32768, 16);

        else

            fir1_i_scaled <= resize(i_scaled, 16);

        end if;

        --//////////////////////////////////////////////////////////
        -- FIR1 Quadrature (Q) Saturation
        --//////////////////////////////////////////////////////////

        if q_scaled > to_signed(32767, 40) then

            fir1_q_scaled <= to_signed(32767, 16);

        elsif q_scaled < to_signed(-32768, 40) then

            fir1_q_scaled <= to_signed(-32768, 16);

        else

            fir1_q_scaled <= resize(q_scaled, 16);

        end if;

    end process;

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: FIR2 In-Phase Channel
    -- Purpose: Filter and decimate the scaled FIR1 I-channel
    --          	samples by an additional factor of 64.
    --//////////////////////////////////////////////////////////////

    fir2_i_inst : fir_filter2
        port map (
            aclk               => clk125,
            aresetn            => dds_resetn,

            s_axis_data_tvalid => fir1_i_valid,
            s_axis_data_tready => fir2_i_ready,
            s_axis_data_tdata  => std_logic_vector(fir1_i_scaled),

            m_axis_data_tvalid => fir2_i_valid,
            m_axis_data_tdata  => fir2_i_data
        );

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: FIR2 Quadrature Channel
    -- Purpose: Filter and decimate the scaled FIR1 Q-channel
    --          	samples by an additional factor of 64.
    --//////////////////////////////////////////////////////////////

    fir2_q_inst : fir_filter2
        port map (
            aclk               => clk125,
            aresetn            => dds_resetn,

            s_axis_data_tvalid => fir1_q_valid,
            s_axis_data_tready => fir2_q_ready,
            s_axis_data_tdata  => std_logic_vector(fir1_q_scaled),

            m_axis_data_tvalid => fir2_q_valid,
            m_axis_data_tdata  => fir2_q_data
        );

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: FIR2 Output Scaling and Saturation
    -- Purpose: Convert the 40-bit signed FIR2 I/Q outputs
    --          into final 16-bit signed audio samples.
    --          Apply arithmetic right shift by 24 bits and
    --          saturate to prevent signed overflow.
    --//////////////////////////////////////////////////////////////

    process (fir2_i_data, fir2_q_data)

        variable i_scaled : signed(39 downto 0);
        variable q_scaled : signed(39 downto 0);

    begin

        -- Scale the full-precision FIR2 outputs
        i_scaled := shift_right(signed(fir2_i_data), 24);
        q_scaled := shift_right(signed(fir2_q_data), 24);

        --//////////////////////////////////////////////////////////
        -- FIR2 In-Phase (I) Saturation
        --//////////////////////////////////////////////////////////

        if i_scaled > to_signed(32767, 40) then

            audio_i_sample <= to_signed(32767, 16);

        elsif i_scaled < to_signed(-32768, 40) then

            audio_i_sample <= to_signed(-32768, 16);

        else

            audio_i_sample <= resize(i_scaled, 16);

        end if;

        --//////////////////////////////////////////////////////////
        -- FIR2 Quadrature (Q) Saturation
        --//////////////////////////////////////////////////////////

        if q_scaled > to_signed(32767, 40) then

            audio_q_sample <= to_signed(32767, 16);

        elsif q_scaled < to_signed(-32768, 40) then

            audio_q_sample <= to_signed(-32768, 16);

        else

            audio_q_sample <= resize(q_scaled, 16);

        end if;

    end process;

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: Stereo Audio Data Assembly
    -- Purpose: Combine the final 16-bit Q and I audio samples
    --          into a single 32-bit AXI-Stream audio word.
    --          Q occupies bits 31:16 and I occupies bits 15:0.
    --//////////////////////////////////////////////////////////////

    stereo_audio_data <= std_logic_vector(audio_q_sample) &
                         std_logic_vector(audio_i_sample);

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: Stereo Audio Valid Generation
    -- Purpose: Assert the stereo output valid signal only
    --          when both FIR2 channels produce valid samples.
    --//////////////////////////////////////////////////////////////

    stereo_audio_valid <= fir2_i_valid and fir2_q_valid;

    --//////////////////////////////////////////////////////////////
    -- Lab 10 Modification: AXI-Stream Master Output
    -- Purpose: Drive the 32-bit stereo audio data and assert
    --          TVALID when both FIR2 channels produce a
    --          valid audio sample pair.
    --//////////////////////////////////////////////////////////////

    m_axis_tdata  <= stereo_audio_data;
    m_axis_tvalid <= stereo_audio_valid;

end architecture rtl;