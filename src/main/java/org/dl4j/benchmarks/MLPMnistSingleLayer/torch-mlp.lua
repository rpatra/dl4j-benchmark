require 'sys'
require 'cunn'
require 'ccn2'
require 'cudnn'

require 'torch'
require 'nn'
require 'image'
cudnn.benchmark = true -- run manual auto-tuner provided by cudnn
cudnn.verbose = false

print('Running on device: ' .. cutorch.getDeviceProperties(cutorch.getDevice()).name)


opt = {
    gpu = true,
    max_epoch = 15,
    trsize_custom = 60000 , -- numExamples
    normalize = true,
    optimization = 'sgd',
    batchSize = 128,
    noutputs = 10,
    ndim = 1,
    row = 28,
    col = 28,
    ninputs = ndim*row*col,
    nhidden = 1000,

}

--print('Load data')
train  = '/train.t7'
test =  '/test.t7'
proj_path = '/resources/'

loaded_train = torch.load(train,'ascii')
loaded_test = torch.load(test,'ascii')
trsize = math.min(loaded_train.labels:size()[1],opt.trsize_custom)
tesize = loaded_test.labels:size()[1]

trainData = {
    --Conversion to double was necessary coz the model:forward() doesnot work on ByteTensor
    data = loaded_train.data[{{1,trsize},{},{},{}}]:double(),
    labels = loaded_train.labels[{{1,trsize}}],
    size = function() return trsize end
}

testData = {
    data = loaded_test.data:double(),
    labels = loaded_test.labels,
    size = function () return tesize end
}

--print(trainData:size())

if opt.normalize == true then
    mean = trainData.data:mean()
    std =  trainData.data:std()
    trainData.data:add(-mean)
    trainData.data:div(std)
    testData.data:add(mean)
    testData.data:div(std)
end

--print('Build model')
model = nn.Sequential()
model:add(nn.Reshape(opt.ninputs))
model:add(nn.Linear(opt.ninputs,opt.nhidden))
model:add(Relu())
model:add(nn.Linear(opt.nhidden,opt.noutputs))
model:add(nn.LogSoftMax())
criterion =  nn.ClassNLLCriterion()

--print('Train')
--trainLogger  = 	optim.Logger(paths.concat(proj_path,'train.log'))
--testLogger  = 	optim.Logger(paths.concat(proj_path,'test.log'))

optimState = {
    learningRate = 0.006,
    weightDecay = 1e-4,
    momentum =  0.9
}
optimMethod = optim.nesterov

function train()

    -- epoch tracker
    epoch = epoch or 1 -- global variable (local keyword is not present)

    local  time = sys.clock()

    -- set model to training mode (for modules that differ in training and testing, like Dropout)
    model:training()

    -- shuffle at each epoch
    shuffle = torch.randperm(trsize)

    -- do one epoch
    print("==> online epoch # " .. epoch .. ' [batchSize = ' .. opt.batchSize .. ']')
    for t=1,trsize,opt.batchSize do

        --display progess
        xlua.progress(t, trsize)


        --create a minibatch
        local inputs = {}
        local targets = {}
        -- print('data',trainData)
        for i = t, math.min(t+opt.batchSize-1,trsize) do

            --load new samples

            local input = trainData.data[shuffle[i]]
            local target = trainData.labels[shuffle[i]]

            table.insert(inputs,input)
            table.insert(targets,target)

        end

        -- create a closure to evaluate f(x) and df(x)/dW i.e. dZ/dW

        local feval =  function(x)
            --get new parameters
            if x ~= parameters then
                parameters:copy(x)
            end

            --reset gradients
            gradParameters:zero()

            --f is the average error of criterion
            f = 0

            --evaluate f and grad for all inputs in a minibatch

            for i=1,#inputs do

                --estimate f

                local output = model:forward(inputs[i])

                local err =  criterion:forward(output,targets[i])
                f = f+err

                --estimate df/dW
                local df_do = criterion:backward(output,targets[i])
                model:backward(inputs[i],df_do)

            end

            f = f/#inputs
            gradParameters:div(#inputs)

            return f,gradParameters


        end

        optimMethod(feval,parameters,optimState)
    end

    --total time taken
    time = sys.clock() - time

    -- time taken by one sample
    time = time/trsize
    print('Time taken to learn 1 sample ' .. (time*1000) .. 'ms')

    epoch =  epoch + 1

end

function test(dataset)
    --print('Evaluate')
    local time = sys.clock()

    -- test over given dataset
    print('<trainer> on testing Set:')
    for t = 1,dataset:size(),opt.batchSize do
        -- disp progress
        xlua.progress(t, dataset:size())

        -- create mini batch
        local inputs = torch.Tensor(opt.batchSize,1,geometry[1],geometry[2])
        local targets = torch.Tensor(opt.batchSize)
        local k = 1
        for i = t,math.min(t+opt.batchSize-1,dataset:size()) do
            -- load new sample
            local sample = dataset[i]
            local input = sample[1]:clone()
            local _,target = sample[2]:clone():max(1)
            target = target:squeeze()
            inputs[k] = input
            targets[k] = target
            k = k + 1
        end

        -- test samples
        local preds = model:forward(inputs)

        -- confusion:
        for i = 1,opt.batchSize do
            confusion:add(preds[i], targets[i])
        end
    end

    -- timing
    time = sys.clock() - time
    time = time / dataset:size()
    print("<trainer> time to test 1 sample = " .. (time*1000) .. 'ms')

    -- print confusion matrix
    print(confusion)
    testLogger:add{['% mean class accuracy (test set)'] = confusion.totalValid * 100}
    confusion:zero()
end

for i=1, opt.max_epoch do
    train()
    test()
end





