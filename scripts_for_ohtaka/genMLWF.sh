#!/bin/sh
#SBATCH -p F4cpu
#SBATCH -N 4
#SBATCH -n 16
#SBATCH -c 32
#SBATCH -o out.o
#SBATCH -t 24:00:00
#SBATCH --exclusive


module purge
ulimit -s unlimited
source /opt/intel/oneapi/setvars.sh
export OMPI_MCA_rmaps_base_mapping_policy=core

nmpi=16
material=GaAs

export MPI_GROUP_MAX=20000
export MPI_COMM_MAX=1000

export OMP_STACKSIZE=1024m
export OMP_NUM_THREADS=32

export I_MPI_PMI_LIBRARY=/usr/lib64/libpmi2.so

genMLWF ${material} -np ${nmpi}