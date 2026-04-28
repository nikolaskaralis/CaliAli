function CaliAli_options = CaliAli_downsample_ucla(varargin)
%% CaliAli_downsample_ucla: Parallel downsampling for UCLA split-video folders.
%
% This entrypoint is intended for datasets where each session is stored as a
% folder containing multiple split video files, for example 1.avi, 2.avi,
% ... 10.avi. It processes the files within each folder in parallel and then
% concatenates their downsampled outputs in natural filename order.
%
% Usage:
%   CaliAli_options = CaliAli_downsample_ucla(CaliAli_options);
%   CaliAli_options = CaliAli_downsample_ucla('C:\data\Session_1');
%   CaliAli_options = CaliAli_downsample_ucla({'C:\data\Session_1','C:\data\Session_2'});

CaliAli_options = parse_ucla_inputs(varargin{:});
opt = CaliAli_options.downsampling;

if isempty(opt.input_files)
    opt.input_files = uipickfiles('Prompt', 'Select one or more UCLA session folders');
end

session_dirs = normalize_session_dirs(opt.input_files);
if isempty(session_dirs)
    error('CaliAli:NoInputFolders', 'CaliAli_downsample_ucla requires one or more input directories.');
end

out_files = cell(1, numel(session_dirs));
for d = 1:numel(session_dirs)
    out_files{d} = process_ucla_folder(session_dirs{d}, opt, CaliAli_options);
end

opt.output_files = out_files;
CaliAli_options.downsampling = opt;
end


function CaliAli_options = parse_ucla_inputs(varargin)
if nargin == 0 || isempty(varargin{1})
    CaliAli_options = CaliAli_parameters();
    return
end

if nargin == 1 && isstruct(varargin{1})
    CaliAli_options = CaliAli_parameters(varargin{1});
    return
end

if nargin == 1 && is_directory_argument(varargin{1})
    CaliAli_options = CaliAli_parameters();
    CaliAli_options.downsampling.input_files = normalize_session_dirs(varargin{1});
    return
end

if all(cellfun(@is_directory_argument, varargin))
    CaliAli_options = CaliAli_parameters();
    CaliAli_options.downsampling.input_files = normalize_session_dirs(varargin);
    return
end

CaliAli_options = CaliAli_parameters(varargin{:});
end


function tf = is_directory_argument(value)
try
    dirs = normalize_session_dirs(value);
    tf = ~isempty(dirs) && all(cellfun(@isfolder, dirs));
catch
    tf = false;
end
end


function session_dirs = normalize_session_dirs(input_files)
if ischar(input_files) || (isstring(input_files) && isscalar(input_files))
    session_dirs = {char(input_files)};
elseif isstring(input_files)
    session_dirs = cellstr(input_files(:)');
elseif iscell(input_files)
    session_dirs = cellfun(@char, input_files(:)', 'UniformOutput', false);
else
    error('CaliAli:InvalidInputFolders', 'Input folders must be a path, string array, or cell array of paths.');
end

session_dirs = session_dirs(~cellfun(@isempty, session_dirs));
not_dirs = session_dirs(~cellfun(@isfolder, session_dirs));
if ~isempty(not_dirs)
    error('CaliAli:InvalidInputFolders', 'All UCLA inputs must be directories. First invalid entry: %s', not_dirs{1});
end
end


function outpath = process_ucla_folder(session_dir, opt, CaliAli_options)
files = dir([session_dir, filesep, '*', char(opt.file_extension)]);
if isempty(files)
    error('CaliAli:NoMatchingFiles', 'No files with extension %s found in %s.', opt.file_extension, session_dir);
end
files = natsortfiles(files);
input_files = fullfile({files.folder}, {files.name});

split_outputs = cell(1, numel(input_files));
fprintf(1, 'Downsampling %d files from %s in parallel...\n', numel(input_files), session_dir);

if isempty(gcp('nocreate'))
    parpool;
end

parfor k = 1:numel(input_files)
    local_options = CaliAli_options;
    local_opt = opt;
    local_opt.input_files = input_files(k);
    local_opt.output_files = {};
    local_opt.keep_split_ds_files = false;
    local_options.downsampling = local_opt;

    local_options = CaliAli_downsample_batch(local_options);
    split_outputs{k} = local_options.downsampling.output_files{1};
end

out_dir = fileparts(split_outputs{1});
[parent_dir, session_name] = fileparts(out_dir);
if isempty(parent_dir)
    parent_dir = out_dir;
end
if ~exist(parent_dir, 'dir')
    mkdir(parent_dir);
end

outpath = fullfile(parent_dir, [session_name '_con.mat']);
CaliAli_concatenate_files(outpath, split_outputs, CaliAli_options);
if ~opt.keep_split_ds_files
    cleanup_split_ds_files(outpath, split_outputs);
end
end
