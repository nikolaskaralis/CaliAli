function test_natural_video_ordering()
%% test_natural_video_ordering: Verify folder-discovered videos use natural order.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repoRoot, 'Other_codes', 'Utilities', 'NaturalSort'));

tmp = tempname;
mkdir(tmp);
cleanup = onCleanup(@() rmdir(tmp, 's'));

names = {'1.avi', '10.avi', '11.avi', '2.avi', '100.avi'};
for k = 1:numel(names)
    fclose(fopen(fullfile(tmp, names{k}), 'w'));
end

files = dir([tmp, filesep, '*.avi']);
files = natsortfiles(files);
actual = {files.name};
expected = {'1.avi', '2.avi', '10.avi', '11.avi', '100.avi'};

assert(isequal(actual, expected), 'Folder-discovered videos were not sorted naturally.');
end
