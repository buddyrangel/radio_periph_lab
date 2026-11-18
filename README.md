# radio_periph_lab

Note : if you are building in windows and vivado is not installed in c:\Xilinx\Vivado\2022.1, you will have to change one thing
I included the settings64.bat file in the make_project.bat just to save a step.  Change that to your Install directory

run make_project.bat (windows) or make_project.sh (linux) to build the project all the way through SD card creation.  You can of course
edit in the GUI and debug in Vitis GUI afterwards as well.  The Vivado project is in "vivado" and the vitis workspace will be in "vitis"

Only downside of this (haven't fixed it yet) the C code for the processor is copied into the Vitis workspace, not linked from the original
version controlled SRC directory.  So, if you change it, you have to copy it back there.  There is a solution to this of course, but haven't 
done it yet

The base distributed project for the radio peripheral laboratory

A couple of other notes to smooth things along :

- Note that the Makefile that is created for you with the Create/Import peripheral wizard doesn't work when you go to build your software Vitis if you are using Windows.  Before packaging your peripheral, make sure to copy the Makefile from the doug_custom peripheral in this repository in place of the Makefile that the tool created as part of your software driver
- I'm not convinced that right clicking on the "Update Hardware Platform" works when you've changed the underlying hardware XSA file.  The safest thing to do here (this is where the script really helps) is to just delete the entire Vitis directory and regenerate it.  To regenerate a Vitis directory (workspace with all the software), you can certainly do it manually as in all the other labs; however I just run the last line of "make_project.bat" from the command prompt
- Make sure to use a standard command prompt, and not the windows powershell.
- If you are experiencing long build times (i.e. waiting for an excessive amount of time for impl_1 to complete) this may be that you don't have enough memory to handle the level of parallelism that I asked for in the script.  Edit "impl.tcl" to change the line from "-jobs 7" to "-jobs 3" if you don't have 16GB of memory.  Your computer probably doesn't have enough memory to synthesize 7 things in parallel, and is constantly swapping to disk

LAB 10 - CUSTOM RADIO PERIPHERAL
================================

Johns Hopkins University
EN.525.742 - System-on-a-Chip
Student: Evaristo Rangel

Development Board: Digilent Zybo Z7-20
Target FPGA: xc7z020clg400-1
Development Software: AMD Vivado 2025.2


1. PROJECT OVERVIEW
===================

This project uses the Digilent Zybo Z7-20 (Zynq-7000)
FPGA development board.

The design is based on the provided radio_periph_lab
project and includes the following modifications:

- Complete digital radio signal-processing chain.
- Fake ADC DDS signal generator.
- Tuner DDS with 31-bit phase accumulator.
- Digital frequency translation and complex mixing.
- Two-stage FIR filtering with decimation.
- Stereo audio output through AXI-Stream.
- AXI-Lite registers for frequency control.
- DDS reset control.
- 32-bit free-running timer for performance measurements.
- Linux C application for radio tuning, musical playback,
&#x20; and AXI-Lite throughput measurement.

The custom radio peripheral is located in:

ip_repo/full_radio


2. AXI-LITE REGISTER MAP
========================

The radio peripheral uses the following memory-mapped
register addresses:

ADDRESS         FUNCTION
-----------------------------------------------
0x43C00000      Fake ADC DDS phase increment
0x43C00004      Tuner DDS phase increment
0x43C00008      DDS reset control
0x43C0000C      Free-running timer (read-only)

The timer increments using the 125 MHz AXI clock.

The Linux application accesses these registers using
the /dev/mem interface and memory mapping.


3. DIGITAL SIGNAL PROCESSING
============================

The radio signal-processing chain includes:

- Fake ADC DDS generating the input signal.
- Tuner DDS generating the frequency reference.
- Complex mixing for digital frequency translation.
- FIR Filter 1 with decimation by 40.
- FIR Filter 2 with decimation by 64.
- Stereo audio samples transmitted through AXI-Stream.

The DDS generators are controlled through the AXI-Lite
register interface.

The design also supports DDS reset and recovery
through the control register.


4. HARDWARE BUILD
=================

Run make_project.bat on Windows from the project
root directory.

The Windows build script supports the local Vivado
installation and includes error checking for project
generation, implementation, and bitstream conversion.

The completed project was successfully built using
AMD Vivado 2025.2.

The hardware build includes:

- Vivado project generation.
- Custom IP integration.
- Synthesis.
- Implementation.
- FPGA bitstream generation.
- Conversion to .bit.bin format.

The generated FPGA binary is located at:

vivado/radio_periph_lab.runs/impl_1/design_1_wrapper.bit.bin

For hardware testing, the generated binary was copied
to the SD card and named:

lab10_full_radio.bit.bin

Generated Vivado project files and bitstreams are
excluded from the GitHub source repository.


5. LOADING THE FPGA BITSTREAM
=============================

On the Zybo Linux system, load the generated FPGA
binary using the following command:

fpgautil -b /run/media/mmcblk0p1/lab10_full_radio.bit.bin

This path assumes the FPGA binary has been copied
to the SD card boot partition.

After loading the FPGA design, initialize the
audio codec using:

sh /run/media/mmcblk0p1/config_codec.sh

The audio codec initialization script must be
available on the SD card.

The FPGA design and audio codec were successfully
initialized on the Zybo Z7-20.


6. LINUX RADIO APPLICATION
==========================

The application source is test_radio.c.

The source file is located in:

src/linux_software/test_radio.c

Copy the application source from the SD card to
the Linux working directory:

cp /run/media/mmcblk0p1/test_radio.c \~/test_radio.c

Compile the application on the Zybo Linux system:

gcc -std=gnu99 -Wall -Wextra test_radio.c -o test_radio

Run the application using:

./test_radio

The application performs the following operations:

- Displays the student name and course information.
- Configures the radio tuner for 30 MHz.
- Generates and plays a musical sequence.
- Reads the AXI-Lite timer register 2,048 times.
- Calculates elapsed time using the 125 MHz clock.
- Calculates and displays transfer throughput in MB/s.

The application requires access to the FPGA
memory-mapped registers and was tested running
as root.

The program compiled successfully without
compiler warnings or errors.


7. HARDWARE VERIFICATION
========================

The completed FPGA design was successfully built,
loaded, and tested on the Zybo Z7-20.

The following functions were verified:

- Successful FPGA configuration through Linux.
- AXI-Lite register read and write operations.
- Free-running timer operation.
- Fake ADC DDS frequency control.
- Tuner DDS frequency control.
- Digital frequency translation.
- FIR filtering and stereo audio output.
- DDS reset and recovery.
- Successful Linux application compilation.
- Audible musical sequence playback.
- AXI-Lite throughput measurement.

The Linux application successfully played a series
of musical notes through the Zybo audio output.


8. AXI-LITE THROUGHPUT BENCHMARK
===============================

The Linux application measures the time required
to perform 2,048 reads of the 32-bit timer register.

The measured transfer size is 8,192 bytes.

VERIFIED BENCHMARK RESULTS
-----------------------------------------------
Timer Reads:             2048
Data Transferred:        8192 bytes
AXI Clock Frequency:     125 MHz
Elapsed Clock Cycles:    71659
Elapsed Time:            0.000573 seconds
Measured Throughput:     14.289902 MB/s
-----------------------------------------------

The throughput calculation uses the elapsed timer
cycles and the total number of bytes transferred.

The reported result represents software-driven
AXI-Lite register-read throughput rather than
the theoretical maximum AXI bus bandwidth.

Results may vary between executions.


9. VIDEO DEMONSTRATION
======================

A video demonstration was recorded showing:

- Digilent Zybo Z7-20 development board.
- Linux terminal executing the test application.
- Student identification displayed in the terminal.
- Radio tuning to 30 MHz.
- Audible musical sequence playback.
- AXI-Lite throughput benchmark results.

The video provides evidence of successful hardware
and Linux software operation.


10. SOURCE CODE AND SUBMISSION
==============================

The completed project source files are maintained
in the following public GitHub repository:

https://github.com/buddyrangel/radio_periph_lab

The repository includes:

- Custom radio peripheral VHDL source files.
- AXI-Lite control interface.
- Radio DSP implementation.
- FIR filter coefficient and IP configuration files.
- DDS IP configuration files.
- Tcl build scripts.
- Windows and Linux build scripts.
- Linux radio test application.
- README and supporting configuration files.

Generated Vivado build directories are excluded
from version control.

The recorded video demonstration is maintained
separately for submission.


11. ORIGINAL PROJECT REFERENCE
==============================

This implementation is based on the laboratory
starter project provided by the instructor:

https://github.com/dougwen/radio_periph_lab

The instructor's original README documentation
is preserved above for reference.


=================================
END OF LAB 10 README
=================================
