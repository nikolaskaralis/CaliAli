function cleanup_split_ds_files(concat_file, split_files)
%% cleanup_split_ds_files: Delete split _ds files after validating _con output.
%
% The concatenated MAT file must contain Y with the same frame size, class,
% and total frame count as the split files. This keeps cleanup from removing
% the only cheap recovery files after a partial or invalid concatenation.

if isempty(split_files)
    return
end
if ischar(split_files) || isstring(split_files)
    split_files = cellstr(split_files);
end

validate_concatenated_output(concat_file, split_files);

for k = 1:numel(split_files)
    if isfile(split_files{k})
        delete(split_files{k});
        fprintf(1, 'Deleted intermediate split file %s\n', split_files{k});
    end
end
end


function validate_concatenated_output(concat_file, split_files)
if ~isfile(concat_file)
    error('CaliAli:MissingConcatenatedFile', 'Cannot delete split files because %s does not exist.', concat_file);
end

m_out = matfile(concat_file);
out_info = whos(m_out, 'Y');
if isempty(out_info) || numel(out_info.size) < 3
    error('CaliAli:InvalidConcatenatedFile', 'Cannot delete split files because %s does not contain a 3-D Y variable.', concat_file);
end

total_frames = 0;
for k = 1:numel(split_files)
    if ~isfile(split_files{k})
        error('CaliAli:MissingSplitFile', 'Cannot validate cleanup because %s does not exist.', split_files{k});
    end

    m_in = matfile(split_files{k});
    in_info = whos(m_in, 'Y');
    if isempty(in_info) || numel(in_info.size) < 3
        error('CaliAli:InvalidSplitFile', 'Cannot delete split files because %s does not contain a 3-D Y variable.', split_files{k});
    end
    if in_info.size(1) ~= out_info.size(1) || in_info.size(2) ~= out_info.size(2)
        error('CaliAli:SplitSizeMismatch', 'Split file %s does not match concatenated frame size.', split_files{k});
    end
    if ~strcmp(in_info.class, out_info.class)
        error('CaliAli:SplitClassMismatch', 'Split file %s does not match concatenated class.', split_files{k});
    end
    total_frames = total_frames + in_info.size(3);
end

if total_frames ~= out_info.size(3)
    error('CaliAli:FrameCountMismatch', 'Cannot delete split files: expected %d concatenated frames, found %d.', total_frames, out_info.size(3));
end
end
