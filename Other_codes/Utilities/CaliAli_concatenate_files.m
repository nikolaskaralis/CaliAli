function out=CaliAli_concatenate_files(outpath,inputh,CaliAli_options)
%% CaliAli_concatenate_files: Concatenate multiple video files into a single file.
%
% This function merges multiple .mat video files into a single output file.
% The resulting concatenated video is saved in the specified output path.
%
% Inputs:
%   outpath         - (Optional) String specifying the output file path.
%                     If not provided, a default name is generated.
%   inputh          - (Optional) Cell array containing paths to input .mat files.
%                     If not provided, a file selection dialog is prompted.
%   CaliAli_options - (Optional) Structure containing processing options.
%
% Outputs:
%   out - Path to the saved concatenated video file.
%
% Usage:
%   out = CaliAli_concatenate_files();  % Interactive file selection
%   out = CaliAli_concatenate_files(outpath, inputh, CaliAli_options);  % Using predefined parameters
%
% Author: Pablo Vergara
% Contact: pablo.vergara.g@ug.uchile.cl
% Date: 2025

if ~exist('outpath','var')
    outpath = [];
end


if ~exist('inputh','var')
    inputh = uipickfiles('FilterSpec','*.mat');
end

if ~exist('CaliAli_options','var')
    CaliAli_options = [];
end



[filepath,name]=fileparts(inputh{end});
if isempty(outpath)
    outpath=strcat(filepath,filesep,name,'_con','.mat');
end
out=outpath;
if ~isfile(outpath)
    % Concatenation preserves inputh order exactly; callers control ordering.
    [d1, d2, total_frames, data_class] = get_concat_metadata(inputh);

    m = matfile(outpath, 'Writable', true);
    m.Y(d1, d2, total_frames) = cast(0, data_class);
    clear m

    save(outpath, 'CaliAli_options', '-append', '-nocompression');

    out_frame = 1;
    for k=progress(1:length(inputh))
        fullFileName = inputh{k};
        m_in = matfile(fullFileName);
        info = whos(m_in, 'Y');
        n_frames = info.size(3);
        chunk_size = resolve_concat_chunk_size([d1, d2], n_frames);
        m_out = matfile(outpath, 'Writable', true);

        for start_frame = 1:chunk_size:n_frames
            end_frame = min(n_frames, start_frame + chunk_size - 1);
            Y = m_in.Y(:, :, start_frame:end_frame);
            write_ix = out_frame:(out_frame + end_frame - start_frame);
            m_out.Y(:, :, write_ix) = Y;
        end
        out_frame = out_frame + n_frames;
    end
else
    fprintf(1, 'File %s already exist in destination folder!\n', out);
end

end


function [d1, d2, total_frames, data_class] = get_concat_metadata(inputh)
total_frames = 0;
d1 = [];
d2 = [];
data_class = '';

for k = 1:length(inputh)
    m = matfile(inputh{k});
    info = whos(m, 'Y');
    if isempty(info) || numel(info.size) < 3
        error('CaliAli:InvalidInput', 'Input file %s does not contain a 3-D Y variable.', inputh{k});
    end

    if isempty(d1)
        d1 = info.size(1);
        d2 = info.size(2);
        data_class = info.class;
    elseif info.size(1) ~= d1 || info.size(2) ~= d2
        error('CaliAli:SizeMismatch', 'Input file %s has size [%d %d], expected [%d %d].', ...
            inputh{k}, info.size(1), info.size(2), d1, d2);
    elseif ~strcmp(info.class, data_class)
        error('CaliAli:ClassMismatch', 'Input file %s has class %s, expected %s.', ...
            inputh{k}, info.class, data_class);
    end

    total_frames = total_frames + info.size(3);
end
end


function chunk_size = resolve_concat_chunk_size(frame_size, max_frames)
try
    [chunk_size, ~] = compute_auto_batch_size('auto', [], frame_size);
catch
    chunk_size = 5000;
end
chunk_size = max(1, min(max_frames, chunk_size));
end


