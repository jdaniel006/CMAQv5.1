#!/bin/csh
cd /opt/CMAQv5.1

#Modificar el config.cmaq
# Modifications in config.cmaq
sed -i 's_\[Add directory path\]_/opt/_' scripts/config.cmaq
sed -i 's/setenv compiler intel/setenv compiler gcc/' scripts/config.cmaq
sed -i 's%setenv netcdf_lib "-lnetcdff -lnetcdf"%setenv netcdf_lib "-lnetcdff -lnetcdf -L/opt/lib -lhdf5hl_fortran -lhdf5_fortran -lhdf5_hl -lhdf5 -lm -lz -lcurl"%' scripts/config.cmaq
sed -i 's/setenv mpi "-lmpich"/setenv mpi "-lmpi"/' scripts/config.cmaq

source /opt/CMAQv5.1/scripts/config.cmaq
#ln -s /d/Users/107538/software/Docker/data /opt/CMAQv5.0.2/data

cd $M3LIB
ln -s /opt/netcdf-4.1.2 netcdf
mkdir $M3LIB/ioapi
cd $M3LIB/ioapi
ln -s /opt/IOAPI/Linux2_x86_64gfort lib
ln -s /opt/IOAPI/Linux2_x86_64gfort include
ln -s /opt/IOAPI/ioapi/fixed_src src
cd $M3LIB
#ln -s /usr/lib64/mpi/gcc/openmpi/lib64 /usr/lib64/mpi/gcc/openmpi/lib
ln -s /usr/lib64/mpi/gcc/openmpi mpi
#setenv LD_LIBRARY_PATH /opt/CMAQv5.1/lib/x86_64/gcc/mpich/lib64
#cd $M3HOME/scripts/stenex
#./bldit.se > bldit.se.log
#./bldit.se_noop > bldit.se_noop.log
#cd $M3HOME/scripts/pario
#./bldit.pario > bldit.pario.log

cd $M3HOME/scripts/build
./bldit.bldmake > bldit.bldmake.log
cd $M3HOME/scripts/icon
./bldit.icon |& tee bldit.icon.profile.log
cd $M3HOME/scripts/bcon
./bldit.bcon |& tee bldit.bcon.profile.log
sed -i 's/&$//' /opt/IOAPI/ioapi/fixed_src/STATE3.EXT

cd $M3HOME/scripts/cctm
./bldit.cctm |& tee bldit.cctm.log
