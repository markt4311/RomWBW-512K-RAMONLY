# RomWBW-512K-RAMONLY
Modified RomWBW for system with 512K RAM and NO ROM

This is modified file from an earlier release of RomWBW:-
Wayne Warthen (wwarthen@gmail.com)
Version 2.9.1-pre.7, 2018-08-28
https://www.retrobrewcomputers.org/

Replace the contents of HBIOS folder

To find the changes in source files search for PLT_MT

Create folder for RAM disk /RomWBW/Source/RomDsk/ROM_320K and add CP/m files as required

Run the modified BuildROM.cmd to build the 512K image, platform=mt, configuration=std, Rom size = 512K
