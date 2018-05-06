lib_name = "liblsl64"
lib_path = ["$(@__DIR__)/lib"]

const LIB = Libdl.find_library(lib_name,lib_path)

forever = 32000000.0

type LslError
    code::Int
end

function _lsl_get_channel_format(o::Ptr{Void})
    ccall((:lsl_get_channel_format,Lsl.LIB),Cint,(Ptr{Void},),o)
end

function _lsl_get_channel_count(o::Ptr{Void})
    ccall((:lsl_get_channel_count,Lsl.LIB),Cint,(Ptr{Void},),o)
end

function _lsl_open_stream(o::Ptr{Void};timeout::Float64=forever)
    er = Ref{Cint}(0)
    ccall((:lsl_open_stream,LIB),Void,(Ptr{Void},Cdouble,Ref{Cint}),o,timeout,er)
    er[] != 0 && throw(LslError(er[]))
end

function _lsl_time_correction(o::Ptr{Void};timeout::Float64=forever)
    er = Ref{Cint}(0)
    offset = ccall((:lsl_time_correction,LIB),Cdouble,(Ptr{Void},Cdouble,Ref{Cint}),o,timeout,er)
    er[] != 0 && throw(LslError(er[]))
    return offset
end
