function createQUTNOISETIMIT(timitfolder)
%
% CREATEQUTNOISETIMIT creates the entire QUT-NOISE-TIMIT database
%
%    CREATEQUTNOISETIMIT(timitfolder) creates the entire QUT-NOISE TIMIT
%      database based upon the QUT-NOISE located in '../QUT-NOISE' and
%      the TIMIT database based in 'timitfolder'. The directory 
%      specified by 'timitfolder' should be the 'timit' directory
%      immediately above the 'doc', 'train' and 'test' folders.
%  
% EXAMPLE:
% 
%   createQUTNOISETIMIT('/work/SAIVT/TIMIT/ORIGCD/timit/')
%
splits = {'t1','t2','t3','t4'};
for i = 1:length(splits)
  batchaddspeechtonoise('../QUT-NOISE', ...
			      '../QUT-NOISE/labels', ...   
			      '../QUT-NOISE/impulses', ...
			      timitfolder, ...  
			      gettxt(['timit.' splits{i} '.wav.list']), ...
			      gettxt(['timit.' splits{i} '.lab.list']), ...
			      '../QUT-NOISE-TIMIT', 16e3, ... 
			      gettxt(['QUT-NOISE-TIMIT.' splits{i} '.wavlist']), ... 
			      'recreate') 
end

