function N = calialiMaxNumCompThreads(varargin)
% calialiMaxNumCompThreads returns the number of available CPU cores, works with
% Windows, Linux, OpenBSD and MAC-OS, using a c-coded mex-file.
%
%   N = calialiMaxNumCompThreads()
%
% Project-local replacement for legacy code that previously called the
% deprecated MATLAB maxNumCompThreads function.

N=feature('Numcores');

