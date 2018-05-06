module Lsl

include("lib.jl")

export StreamInfo,InletStream
export DataSample,DataArray
export resolve,name,open,pull_sample

type StreamInfo
    o::Ptr{Void}
end

function resolve(prop::String,value::String;num::Int=1,timeout::Float64=forever)
    buffersize = num+100
    buffer = Vector{Ptr{Void}}(buffersize)
    num = ccall((:lsl_resolve_byprop,LIB),Int,(Ref{Ptr{Void}},Cint,Cstring,Cstring,Cint,Cdouble),buffer,buffersize,prop,value,num,timeout)
    return [StreamInfo(o) for o in buffer[1:num]]
end

function resolve_eeg()
    resolve("type","EEG")[1]
end

function name(info::StreamInfo)
    unsafe_string(ccall((:lsl_get_name,LIB),Cstring,(Ptr{Void},),info.o))
end

type InletStream
    o::Ptr{Void}
    format::Type
    num_channels::Int
    pull_cmd::Ptr{Void}
end

ChannelFormats = [Cfloat,Cdouble,Cstring,Cint,Cshort,Cuchar,Clong]
pull_sample_cmds = [Symbol("lsl_pull_sample_$x") for x in ["f","d","str","i","s","c","l"]]

function InletStream(info::StreamInfo,bufflen::Int=360,chunklen::Int=0,recover::Bool=true)
    o = ccall((:lsl_create_inlet,LIB),Ptr{Void},(Ptr{Void},Cint,Cint,Cint),info.o,bufflen,chunklen,recover ? 1 : 0)
    f = _lsl_get_channel_format(info.o)
    c = _lsl_get_channel_count(info.o)
    h = Libdl.dlopen(LIB)
    p = Libdl.dlsym(h,pull_sample_cmds[f])
    Libdl.dlclose(h)
    return InletStream(o,ChannelFormats[f],c,p)
end

import Base.open
function open(inlet::InletStream;timeout::Float64=forever)
    _lsl_open_stream(inlet.o;timeout=timeout)
end

type DataSample{T<:Union{ChannelFormats...}}
    time::Float64
    value::Vector{T}
end

type DataArray{T<:Union{ChannelFormats...}}
    times::Vector{Float64}
    values::Array{T,2}
end


ElementalChannelFormats = [Cfloat,Cdouble,Cint,Cshort,Cuchar,Clong]

for f in ElementalChannelFormats
    eval(quote
        function pull_sample(::Type{$f},inlet::InletStream;timeout::Float64=forever)
            er = Ref{Cint}(0)
            buffer = Vector{$f}(inlet.num_channels)
            time_double = ccall(inlet.pull_cmd,Cdouble,(Ptr{Void},Ref{$f},Cint,Cdouble,Ref{Cint}),inlet.o,buffer,inlet.num_channels,timeout,er)
            er[] != 0 && throw(LslError(er[]))
            return (time_double,buffer)
        end
    end)
end

pull_sample(inlet::InletStream;timeout::Float64=forever) = pull_sample(inlet.format,inlet;timeout=timeout)

function pull_samples(inlet::InletStream,n::Int=25000;timeout::Float64=forever)
    data = inlet.format[]
    times = Float64[]
    offsets = Float64[]
    while length(data)<n
        (t,d) = pull_sample(inlet,timeout=timeout)
        c = _lsl_time_correction(inlet.o)
        push!(times,t)
        append!(data,d)
        push!(offsets,c)
    end
    return (DataArray(times,reshape(data,(inlet.num_channels,:))),offsets)
end

end
