#!/bin/sh
#SBATCH -p L4cpu
#SBATCH -N 4
#SBATCH -n 64
#SBATCH -c 8
#SBATCH -o out.o
#SBATCH -t 120:00:00
#SBATCH --exclusive

module purge
ulimit -s unlimited
source /opt/intel/oneapi/setvars.sh

export MPI_GROUP_MAX=20000
export MPI_COMM_MAX=1000

export OMP_STACKSIZE=1024m
export OMP_NUM_THREADS=8

nmpi=64
nmpi_band=64
itenum=4
material=GaAs

last_iter=$(ls QPU.*run 2>/dev/null | sed -E 's/QPU\.([0-9]+)run/\1/' | sort -n | tail -1)
if [[ -z "$last_iter" ]]; then
    last_iter=0
fi

for ((i=1; i<=itenum; i++)); do
    echo "Iteration $((i+last_iter)) / $((itenum+last_iter))"

    gwsc -np ${nmpi} 1 ${material}
    job_band ${material} -np ${nmpi_band}
    
    python ecalj_band.py
    mv bandfig/ecalj_band.png bandfig/ecalj_band_$((i+last_iter)).png
    #for magnetide
    #mv bandfig/ecalj_band.spin1.png bandfig/ecalj_band_$((i+last_iter)).spin1.png
    #mv bandfig/ecalj_band.spin2.png bandfig/ecalj_band_$((i+last_iter)).spin2.png
    cp bnd* QSGW.$((i+last_iter))run/

    echo "Done iteration $((i+last_iter))"
    date
done