function test_acceleration_io()
%% test_acceleration_io: Verify streaming concatenation and grouped preallocation.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(repoRoot));

tmp = tempname;
mkdir(tmp);
cleanup = onCleanup(@() rmdir(tmp, 's'));

Y = uint16(reshape(1:12, 2, 2, 3));
f1 = fullfile(tmp, '1_ds.mat');
f2 = fullfile(tmp, '2_ds.mat');
save(f1, 'Y', '-v7.3', '-nocompression');
Y = uint16(reshape(13:24, 2, 2, 3));
save(f2, 'Y', '-v7.3', '-nocompression');

out = fullfile(tmp, 'session_con.mat');
CaliAli_concatenate_files(out, {f1, f2}, []);
m = matfile(out);
assert(isequal(size(m, 'Y'), [2 2 6]), 'Concatenated output has wrong size.');
vars = who(m);
assert(any(strcmp(vars, 'CaliAli_options')), 'Concatenated output should preserve CaliAli_options variable.');
assert(isequal(m.Y(:, :, 1), uint16(reshape(1:4, 2, 2))), 'First frame order changed.');
assert(isequal(m.Y(:, :, 6), uint16(reshape(21:24, 2, 2))), 'Last frame order changed.');
cleanup_split_ds_files(out, {f1, f2});
assert(~isfile(f1) && ~isfile(f2), 'Intermediate split files were not deleted after validation.');

batches = {
    {out, 1, 1, 2, fullfile(tmp, 'session_mc.mat')}, ...
    {out, 1, 3, 6, fullfile(tmp, 'session_mc.mat')}};
[flags, outputs] = pre_allocate_outputs(batches, '_mc');
assert(all(flags), 'Expected both new batches to need processing.');
assert(numel(unique(outputs)) == 1, 'Batches should map to one grouped output.');
m2 = matfile(outputs{1});
assert(isequal(size(m2, 'Y'), [2 2 6]), 'Preallocated batch output has wrong size.');
end
