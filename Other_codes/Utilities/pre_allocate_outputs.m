function [process_flags,out] = pre_allocate_outputs(input_files,tag)
%% pre_allocate_outputs: Pre-allocate output files and determine processing flags.
%
% Inputs:
%   input_files - Cell array containing either:
%                 - Strings (original filenames)
%                 - Cell arrays {filename, session_id, start_frame, end_frame, output_filename}
%
% Outputs:
%   process_flags - Logical array indicating which items need processing (true = process, false = skip)
%
% Usage:
%   process_flags = pre_allocate_outputs(opt.input_files);
%
% Author: Pablo Vergara
% Contact: pablo.vergara.g@ug.uchile.cl
% Date: 2025

process_flags = false(1, length(input_files));
out = cell(1, length(input_files));

output_files = cellfun(@(x) resolve_output_file(x, tag), input_files, 'UniformOutput', false);
remove_corrupted_output(unique(output_files, 'stable'));

for k = 1:length(input_files)
    out{k} = output_files{k};
end

is_batch = cellfun(@iscell, input_files);

for k = find(~is_batch)
    output_file = output_files{k};
    if ~isfile(output_file)
        process_flags(k) = true;
    else
        fprintf(1, 'File %s already exists!\n', output_file);
    end
end

batch_outputs = unique(output_files(is_batch), 'stable');
for g = 1:numel(batch_outputs)
    output_file = batch_outputs{g};
    group_ix = find(is_batch & strcmp(output_files, output_file));

    if isfile(output_file)
        fprintf(1, 'Batched output file %s already exists!\n', output_file);
        process_flags(group_ix) = false;
        continue
    end

    fprintf(1, 'Pre-allocating output file: %s\n', output_file);
    [d1, d2, total_frames, data_class] = get_batch_output_metadata(input_files(group_ix));
    if total_frames > 0
        m = matfile(output_file, 'Writable', true);
        m.Y(d1, d2, total_frames) = cast(0, data_class);
        fprintf(1, 'Pre-allocated file with dimensions [%d, %d, %d]\n', d1, d2, total_frames);
    end
    process_flags(group_ix) = true;
end

end


function output_file = resolve_output_file(input_entry, tag)
if ischar(input_entry) || (isstring(input_entry) && isscalar(input_entry))
    filename = char(input_entry);
elseif iscell(input_entry) && numel(input_entry) >= 5
    output_file = input_entry{5};
    return
else
    error('CaliAli:InvalidInput', 'Unsupported input file entry.');
end

[filepath, name] = fileparts(filename);
if ~contains(name, tag)
    output_file = char(strcat(filepath, filesep, name, tag, '.mat'));
else
    output_file = char(strcat(filepath, filesep, name, '.mat'));
end
end


function [d1, d2, total_frames, data_class] = get_batch_output_metadata(group_entries)
total_frames = 0;
d1 = 0;
d2 = 0;
data_class = 'uint16';

for j = 1:numel(group_entries)
    batch_info = group_entries{j};
    total_frames = total_frames + batch_info{4} - batch_info{3} + 1;

    if d1 == 0
        dims = get_data_dimension(batch_info{1});
        d1 = dims(1);
        d2 = dims(2);
        try
            m = matfile(batch_info{1});
            info = whos(m, 'Y');
            if ~isempty(info)
                data_class = info.class;
            end
        catch
            data_class = 'uint16';
        end
    end
end
end
