function [Mr,Ref,template]=Rigid_mc(Y,opt,template)
%% Rigid_mc: Perform rigid motion correction using NoRMCorre.
%
% This function applies rigid motion correction to a 3D image volume using
% the NoRMCorre algorithm. The correction is based on a reference projection
% that can be computed using blood vessel extraction or background removal.
%
% Inputs:
%   Y   - 3D image volume to be motion corrected.
%   opt - Structure containing motion correction options.
%
% Outputs:
%   Mr  - Motion-corrected 3D image volume.
%   Ref - Reference projection used for motion correction.
%
% Usage:
%   [Mr, Ref] = Rigid_mc(Y, opt);
%
% Author: Written by Pablo Vergara utilizing the codes of Eftychios A. Pnevmatikakis
%            Simons Foundation, 2016
% Contact: pablo.vergara.g@ug.uchile.cl
% Date: 2025

fprintf('Appling translation motion correction...\n');
if nargin < 3
    template = [];
end
% Generate reference projection based on specified option.
if strcmp(opt.reference_projection_rigid,'BV')
    Ref=CaliAli_get_blood_vessels(Y,opt); % Correct for vignetting.
elseif strcmp(opt.reference_projection_rigid,'neuron')
    Ref=CaliAli_remove_background(Y,opt); % Remove background.
end

[d1,d2,~] = size(Ref);
b1=round(d1/10); % Border size for cropping.
b2=round(d2/10);
use_parallel = ~isfield(opt, 'use_parallel') || opt.use_parallel;

% Determine binning size for NoRMCorre.
if size(Y,3)<200
    binz=size(Y,3);
else
    binz=200;
end

% Set NoRMCorre parameters.
options_r = NoRMCorreSetParms('d1',d1-b1*2,'d2',d2-b2*2,'bin_width',binz,'max_shift',20,'iter',1,'correct_bidir',false);
if isfield(opt, 'shifts_method') && ~isempty(opt.shifts_method)
    options_r.shifts_method = opt.shifts_method;
end
options_r.use_parallel = use_parallel;

% Perform motion correction on cropped reference.
if isempty(template)
    tic; [~,shifts,template] = normcorre_batch(Ref(b1+1:d1-b1,b2+1:d2-b2,:),options_r); toc
else
    tic; [~,shifts,template] = normcorre_batch(Ref(b1+1:d1-b1,b2+1:d2-b2,:),options_r,template); toc
end

% Apply shifts to each frame.
Mr = zeros(size(Y), 'like', Y);
needs_ref = isfield(opt, 'do_non_rigid') && opt.do_non_rigid;
Ref_shifted = [];
if needs_ref
    Ref = v2uint16(Ref); % Convert to uint16 only when non-rigid correction needs it.
    Ref_shifted = zeros(size(Ref), 'like', Ref);
end

use_fast_shift = isfield(opt, 'use_fast_shift') && opt.use_fast_shift;
if use_fast_shift && exist('apply_shifts', 'file') == 2
    apply_opts = NoRMCorreSetParms( ...
        'd1', size(Y, 1), ...
        'd2', size(Y, 2), ...
        'output_type', 'mat', ...
        'shifts_method', 'linear');
    apply_opts.boundary = 'zero';
    apply_opts.add_value = 0;
    apply_opts.correct_bidir = false;
    apply_opts.nFrames = size(Y, 3);
    Mr = apply_shifts(Y, shifts, apply_opts, 0, 0, 0);
    if needs_ref
        Ref_shifted = apply_shifts(Ref, shifts, apply_opts, 0, 0, 0);
    end
else
    if use_parallel
        parfor i = 1:size(Y,3)
            Mr(:,:,i) = imtranslate(Y(:,:,i)+1,flip(squeeze(shifts(i).shifts)'),'FillValues',0);
            if needs_ref
                Ref_shifted(:,:,i) = imtranslate(Ref(:,:,i)+1,flip(squeeze(shifts(i).shifts)'),'FillValues',0);
            end
        end
    else
        for i = 1:size(Y,3)
            Mr(:,:,i) = imtranslate(Y(:,:,i)+1,flip(squeeze(shifts(i).shifts)'),'FillValues',0);
            if needs_ref
                Ref_shifted(:,:,i) = imtranslate(Ref(:,:,i)+1,flip(squeeze(shifts(i).shifts)'),'FillValues',0);
            end
        end
    end
end
if needs_ref
    Ref = Ref_shifted;
else
    Ref = [];
end
end
