#SBATCH -p F1cpu
#SBATCH -N 1
#SBATCH -n 8
#SBATCH -c 1
#SBATCH -o out.o
#SBATCH -t 24:00:00
#SBATCH --exclusive

module purge
ulimit -s unlimited
source /opt/intel/oneapi/setvars.sh

material=GaAs

export MPI_GROUP_MAX=20000
export MPI_COMM_MAX=1000

export OMP_STACKSIZE=512m
export OMP_NUM_THREADS=1

mpirun -np 8 lmf ${material}