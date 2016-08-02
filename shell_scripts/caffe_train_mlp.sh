#!/usr/bin/env sh

read -p "CPU, GPU, or MULTI?" yn
case $yn in
    'CPU' ) time $HOME/caffe/build/tools/caffe train --solver=src/main/java/org/dl4j/benchmarks/MLPMnistSingleLayer/caffe_mlp_solver.prototxt;;
    'GPU' ) time $HOME/caffe/build/tools/caffe train --solver=src/main/java/org/dl4j/benchmarks/MLPMnistSingleLayer/caffe_mlp_solver.prototxt -gpu 0;;
    'MULTI' ) time $HOME/caffe/build/tools/caffe train --solver=src/main/java/org/dl4j/benchmarks/MLPMnistSingleLayer/caffe_mlp_solver.prototxt -gpu all;;
    *) echo "Invalid response";;
esac
