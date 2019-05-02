module MSQR
export MSQRpar
export MSQRtrain

# include("MPSSwapTest.jl")

using Yao, Yao.ConstGate
using MPSCircuit
push!(LOAD_PATH,abspath("src")) 
using MPSSwapTest
using Flux.Optimise
using LinearAlgebra

# Structure of parameters for MSQR training. 
mutable struct MSQRpar
    circuit::ChainBlock
    reg::DefaultRegister
    vBit::Int64
    rBit::Int64
end

# MSQR training function.
function MSQRtrain(par::MSQRpar, nMeasure::Int64, nTrain::Int64; learningRate=0.1, show::Bool=false)
    circuit = par.circuit
    regTar = par.reg
    nBitT = nqubits(regTar)
    vBit = par.vBit
    rBit = par.rBit
    dGates = collect_blocks(AbstractDiff, circuit)
    # println("t1")
    if show
        println("\nTraining Parameters:")
        println("nBitT=$(nBitT) vBit=$(vBit) rBit=$(rBit)")
        println("nMeasure=$(nMeasure) nTrain=$(nTrain) learningRate=$(learningRate)\n")
        println("Initial overlap = $(MSTest(regTar, circuit, vBit, rBit, nMeasure).overlaps)")
    end
    for i=1:nTrain
        mst = MSTest(regTar, circuit, vBit, rBit, nMeasure)
        # println("t2")
        if learningRate == "ADAM"
            nBitA = nqubits(mst.regA)
            witnessOp = matblock(diagm(0=>ones(1<<nBitA)) - mat(mst.witnessOp))
        else
            witnessOp = mst.witnessOp
        end
        grads = opdiff.(()->MSTest(regTar, circuit, vBit, rBit, nMeasure).regA, dGates,Ref(witnessOp))
        # println("t3")
        if learningRate == "ADAM"
            # println("t3_1")
            dGatesPar = [parameters(dGates[i])[1] for i=1:length(dGates)]
            # println("t3_2")
            Optimise.update!(ADAM(0.1), dGatesPar, grads)
            # println("t3_3")
            dispatch!.(dGates, dGatesPar)
        else
            dispatch!.(+, dGates, grads.*learningRate)
        end
        # println("t4")
        showCase = (25*i)%nTrain==0
        if  showCase && show
            println("Training Step $(i), overlap = $(mst.overlaps)")
        end
        # println("t5")
    end
    circuit
end

end

