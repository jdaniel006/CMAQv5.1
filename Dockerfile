FROM opensuse:tumbleweed
MAINTAINER josedaniel.gomezdesegura@tecnalia.com
LABEL cmaq.version="5.1" \
ioapi.version="3.2" \
netcdf.version="4.1.2" \
OS="openSuse" \
OS.version="tumbleweed" \
cmaq.user="root"
#RUN zypper -n update # Discouraged in installation guide

# Install needed O.S. packages
RUN zypper -n install tcsh \
        gcc \
        gcc-fortran \
        gcc-c++ \
        make \
        vim \
        wget \
        git \
        tar \
        openmpi-devel \
        time \
        which\
        libssh2-devel \
        libopenssl-devel


# To investigate: run everything as an unprivileged user
#RUN useradd -d /home/meteo -m meteo
#USER meteo

# Some variables
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/lib64/mpi/gcc/openmpi/bin:/opt/bin
ENV LD_LIBRARY_PATH=/opt/lib
ENV BIN=Linux2_x86_64gfort

# Download CMAQ v5.1
RUN git clone -b 5.1 https://github.com/CMASCenter/CMAQ.git /opt/CMAQv5.1

# Uncomment if you want to use container internal directory to store inputs and outputs
# Otherwise, we will use a shared directory
#RUN wget ftp://ftp.unc.edu/pub/cmas/SOFTWARE2/MODELS/CMAQ/5.0.2/DATA.CMAQv5.0.2.Apr2014.tar.gz
#RUN wget ftp://ftp.unc.edu/pub/cmas/SOFTWARE2/MODELS/CMAQ/5.0.2/TOOLS.CMAQv5.0.2.Apr2014.tar.gz
#RUN /bin/tar -zxvf /DATA.CMAQv5.0.2.Apr2014.tar.gz

# zlib installation
RUN cd /opt ;\
wget -q http://zlib.net/zlib-1.2.8.tar.gz ;\
tar -zxf zlib-1.2.8.tar.gz
RUN cd /opt/zlib-1.2.8 ; \
./configure --prefix=/opt/ ;\
make ;\
make install

# curl installation
# Modified to support SSL
RUN cd /opt ;\
wget -q https://curl.haxx.se/download/curl-7.48.0.tar.gz ;\
tar -zxf curl-7.48.0.tar.gz
RUN cd /opt/curl-7.48.0 ; \
./configure --prefix=/opt/ --with-zlib=/opt  --with-libssh2 ;\
make ;\
make install

# HDF5 installation

RUN cd /opt ;\
wget -q http://www.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-1.10.0/src/hdf5-1.10.0.tar.gz ;\
tar -zxf hdf5-1.10.0.tar.gz
RUN cd /opt/hdf5-1.10.0 ; \
./configure --prefix=/opt/ --with-zlib=/opt/include,/opt/lib --enable-fortran ;\
make ;\
make install

# netCDF installation
RUN cd /opt ;\
wget -q ftp://ftp.unidata.ucar.edu/pub/netcdf/old/netcdf-4.1.2.tar.gz ;\
tar -zxf netcdf-4.1.2.tar.gz

RUN cd /opt/netcdf-4.1.2 ; \
./configure --with-hdf5=/opt --prefix=/opt ;\
sed -i 's|hid_t target_nc_typeid|nc_type target_nc_typeid|' libsrc4/nc4internal.h ;\
make ;\
make install

# IOAPI installation
# New - 2016-12-05 - Changed to cjcoats github repository to download IOAPI 3.2
RUN cd /opt ;\
        git clone https://github.com/cjcoats/ioapi-3.2 ;\
        mv ioapi-3.2 IOAPI ;\
        cd IOAPI ;\
# Modificaciones del Makefile para nocpl y nuestros directorios
        cp Makefile.template  Makefile ;\
# Makefile modifications: nocpl and use our directories
        sed -i 's|Linux2_x86_64.*|Linux2_x86_64gfort|' Makefile ;\
        sed -i '/^BASEDIR.*/c\BASEDIR = /opt/IOAPI' Makefile ;\
        sed -i 's|${HOME}.*|/opt|' Makefile ;\
        sed -i '/^NCFLIBS.*/c\NCFLIBS   = "-lnetcdff -lnetcdf -lhdf5hl_fortran -lhdf5_fortran -lhdf5_hl -lhdf5  -lm -lz -lcurl"' Makefile ;\
        sed -i '/TESTDIR/d' Makefile ;\
        sed -i '/RTTDIR/d' Makefile ;\
        make dirs

RUN cp /opt/lib/libnetcdf.a \
        /opt/lib/libnetcdff.a \
        /opt/IOAPI/Linux2_x86_64gfort


RUN cd /opt/IOAPI ; make configure; \
        sed -i '/^ LIBS = -L${OBJDIR}.*/c\LIBS = -L${OBJDIR} -L/opt/lib -lioapi -lnetcdff -lnetcdf -lhdf5hl_fortran -lhdf5_fortran -lhdf5_hl -lhdf5 -lm -lz -lcurl $(OMPLIBS) $(ARCHLIB) $(ARCHLIBS)'  m3tools/Makefile.nocpl.sed ;\
        cp ioapi/*.EXT ioapi/fixed_src ;\
        make BIN=Linux2_x86_64gfort


# CMAQ 5.1
ENV LD_LIBRARY_PATH=/opt/lib/:/usr/lib64/mpi/gcc/openmpi/lib64

# Copy compile script and execute it
COPY compile.csh /opt/CMAQv5.1/
RUN chmod 755 /opt/CMAQv5.1/compile.csh
RUN /opt/CMAQv5.1/compile.csh

#RUN mkdir /opt/CMAQv5.1/data
RUN echo source /opt/CMAQv5.1/scripts/config.cmaq > /root/.cshrc
RUN echo setenv LD_LIBRARY_PATH /opt/lib:/opt/CMAQv5.1/lib/x86_64/gcc/mpich/lib64 >> /root/.cshrc
# Unlimit does not work in container, therefore:
RUN sed -i s/unlimit/#unlimit/ /opt/CMAQv5.1/scripts/icon/run.icon ;\
         sed -i s/unlimit/#unlimit/ /opt/CMAQv5.1/scripts/bcon/run.bcon ;\
         sed -i s/unlimit/#unlimit/ /opt/CMAQv5.1/scripts/cctm/run.cctm

# In case sshd is needed (maybe for mpirun, in the future)
# A new public key must be generated
RUN /usr/bin/ssh-keygen -A
COPY id_rsa.pub /root/.ssh/authorized_keys
RUN chmod 700 /root/.ssh/authorized_keys
COPY id_rsa /root/.ssh/
RUN chmod 700 /root/.ssh/id_rsa
EXPOSE 22

# Ready to connect to a shell to run the commands.
# It could be automated, however this is a demonstrative exercise.
#ENTRYPOINT ["/bin/csh"]

# If mpirun finally works...:
ENTRYPOINT ["/usr/sbin/sshd", "-D"]

#Para ejecutar
# Borrar unlimit de run.icon, run.bcon, y antes exportar LD_LIBRARY_PATH con /opt/lib
# CMAQ execution
# Delete unlimit instructions from run.icon, run.bcon and export LD_LIBRARY_PATH as /opt/lib
