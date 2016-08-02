package org.dl4j.benchmarks.Utils;

import org.deeplearning4j.datasets.iterator.MultipleEpochsIterator;
import org.deeplearning4j.nn.multilayer.MultiLayerNetwork;
import org.deeplearning4j.parallelism.ParallelWrapper;
import org.nd4j.jita.conf.CudaEnvironment;
import org.nd4j.linalg.dataset.api.iterator.DataSetIterator;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.concurrent.TimeUnit;

/**
 */
public class BenchmarkUtil {
    private static Logger log = LoggerFactory.getLogger(BenchmarkUtil.class);
    public final static int buffer = 8;
    public final static int avgFrequency = 3;

    public static void printTime(String name, long ms){
        log.info(name + " time: {} min, {} sec | {} milliseconds",
                TimeUnit.MILLISECONDS.toMinutes(ms),
                TimeUnit.MILLISECONDS.toSeconds(ms) -
                        TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS.toMinutes(ms)),
                ms);

    }

    public static ParallelWrapper multiGPUModel(MultiLayerNetwork network, int buffer, int workers, int avgFrequency) {
        return new ParallelWrapper.Builder(network)
                .prefetchBuffer(buffer)
                .workers(workers)
                .averagingFrequency(avgFrequency)
                .build();
    }

    public static void train(MultiLayerNetwork network, int numGPUWorkers, DataSetIterator data){
        if(numGPUWorkers > 1) {
            CudaEnvironment.getInstance().getConfiguration().allowMultiGPU(true).allowCrossDeviceAccess(true);
            ParallelWrapper wrapper = multiGPUModel(network, buffer, numGPUWorkers, avgFrequency);
            wrapper.fit(data);
        } else {
            network.fit(data);
        }

    }

}
