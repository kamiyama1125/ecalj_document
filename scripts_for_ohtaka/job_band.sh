#!/bin/sh
#SBATCH -p F1cpu
#SBATCH -N 1
#SBATCH -n 8
#SBATCH -c 1
#SBATCH -o out.o
#SBATCH -t 24:00:00
#SBATCH --exclusive


source /opt/intel/oneapi/setvars.sh
module purge
ulimit -s unlimited

material=GaAs

export MPI_GROUP_MAX=20000
export MPI_COMM_MAX=1000

export OMP_STACKSIZE=1024m
export OMP_NUM_THREADS=1

job_band ${material} -np 8
