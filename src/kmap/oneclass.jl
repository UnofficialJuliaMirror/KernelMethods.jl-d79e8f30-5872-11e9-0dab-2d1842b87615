using StatsBase: countmap
import StatsBase: fit

export OneClassClassifier, OneClassClassifierFFT, regions, centroid, fit, predict

mutable struct OneClassClassifier{T}
    centers::Vector{T}
    freqs::Vector{Int}
    n::Int
    epsilon::Float64
end

abstract type OneClassClassifierFFT end

function fit(::Type{OneClassClassifierFFT}, dist::Function, X::AbstractVector{T}, m::Int) where T
    Q = fftclustering(dist, X, m)
    C = X[Q.irefs]
    P = Dict(Q.irefs[i] => i for i in eachindex(Q.irefs))
    freqs = zeros(Int, length(Q.irefs))
    for nn in Q.NN
        freqs[P[first(nn).objID]] += 1
    end
    OneClassClassifier(C, freqs, length(X), Q.dmax)
end

function regions(X, refs::Index)
    I = KMap.invindex(l2_distance, X, refs, k=1)
    (freqs=[length(lst) for lst in I], regions=I)
end

function regions(X, refs)
    regions(X, fit(Sequential, refs))
end

function centroid(D)
    sum(D) ./ length(D)
end

function centroid_correction(X, C)
    [centroid(X[lst]) for lst in regions(X, C).regions if length(lst) > 0]
end

function predict(occ::OneClassClassifier{T}, dist::Function, q::T) where T
    seq = fit(Sequential, occ.centers)
    res = search(seq, dist, q, KnnResult(1))
    #1.0 - first(res).dist  / occ.epsilon
    (similarity=max(0.0, 1.0 - first(res).dist  / occ.epsilon), freq=occ.freqs[first(res).objID])
    #occ.freqs[first(res).objID] / occ.n
end