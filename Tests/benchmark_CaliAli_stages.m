function results = benchmark_CaliAli_stages(CaliAli_options, stages)
%% benchmark_CaliAli_stages: Time major CaliAli pipeline stages.
%
% Usage:
%   opts = CaliAli_demo_parameters();
%   results = benchmark_CaliAli_stages(opts);
%   results = benchmark_CaliAli_stages(opts, {'downsample','motion'});

if nargin < 2 || isempty(stages)
    stages = {'downsample','motion','alignment','cnmf'};
end
if ischar(stages) || isstring(stages)
    stages = cellstr(stages);
end

results = table('Size', [0 3], ...
    'VariableTypes', {'string','double','logical'}, ...
    'VariableNames', {'Stage','Seconds','Succeeded'});

for k = 1:numel(stages)
    stage = lower(char(stages{k}));
    t = tic;
    ok = true;
    try
        switch stage
            case {'downsample','downsampling'}
                CaliAli_options = CaliAli_downsample_batch(CaliAli_options);
            case {'motion','motion_correction'}
                CaliAli_options.motion_correction.input_files = CaliAli_options.downsampling.output_files;
                CaliAli_options = CaliAli_motion_correction(CaliAli_options);
            case {'alignment','inter_session_alignment'}
                CaliAli_options.inter_session_alignment.input_files = CaliAli_options.motion_correction.output_files;
                CaliAli_options = CaliAli_align_sessions(CaliAli_options);
            case {'cnmf','source_extraction'}
                runCNMFe(CaliAli_options.inter_session_alignment.out_aligned_sessions);
            otherwise
                error('CaliAli:UnknownBenchmarkStage', 'Unknown benchmark stage "%s".', stage);
        end
    catch ME
        ok = false;
        warning('CaliAli:BenchmarkStageFailed', 'Stage %s failed: %s', stage, ME.message);
    end
    results = [results; {string(stage), toc(t), ok}]; %#ok<AGROW>
end
end
