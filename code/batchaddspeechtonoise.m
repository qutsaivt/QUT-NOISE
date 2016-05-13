function id = batchaddspeechtonoise(wavfolder, labelfolder, ...
				     impulsefolder, speechfolder, ...
				     speechlist, speechlablist, ...
				     outfolder, wantedfs, wavname, ...
				     splitname, startid, countv, noiselengths, ...
				     snrs, speechpercentv, concatprob, maxoverlap) 
%
% BATCHADDSPEECHTONOISE creates a batch of noisy sequences
%
%   BATCHADDSPEECHTONOISE(wavfolder, labelfolder,
%     impulsefolder, speechfolder, speechlist, speechlablist,
%     outfolder, wantedfs, wavname, splitname, startid, count,
%     noiselengths, snrs[, speechpercent [, concatprob[,
%     maxoverlap]]]) creates 'count' instances of the specified
%     noisy speech sequence files. 'noiselengths' and 'snrs' can be
%     vectors to create multiple instances of 'count' files. 
%
%     If splitname is a cell array (i.e: {'A','B'}) then the split
%     names are cycled between each name in the array in each 'count'.
%
%     'speechpercent' can either be a single number or [min,max] to
%     specify the bounds of the number. The default is [0,1]. If
%     only a single number is specified, the algorithm will attempt
%     to get close to that number, but it is not guaranteed. If a
%     [min,max] range is specified, it will ensure that it remains
%     within it. NOTE that unrealisticly tight range specifications 
%     could result in very long search times for a suitable
%     combination. 
%
%     If multiple rows of speechpercent ranges are provided,
%     (ie. [min1,max2; min2, max2] then 'count' files will be
%     created in each range. If multiple 'counts' are provided then
%     then number of 'counts' should match the number of rows of
%     'speechpercent's and each 'speechpercent' will create the
%     corresponding number of files.
%
%   BATCHADDSPEECHTONOISE(wavfolder, labelfolder,
%     impulsefolder, speechfolder, speechlist, speechlablist,
%     outfolder, wantedfs, speechsequencename, 'recreate') attempts
%     to recreate the  final speech sequence file
%     'speechsequencename'.  'speechsequencename' can also be a
%     cell-array of strings to recreate many files.   
%
%   id = BATCHADDSPEECHTONOISE(...) returns the last id
%     assigned in the batch creation.
%
% EXAMPLE:
% % creating new files
% batchaddspeechtonoise('../QUT-NOISE', '../QUT-NOISE/labels', ... 
%   '../QUT-NOISE/impulses', '/work/SAIVT/TIMIT/ORIGCD/timit/', ...
%   gettxt('timit.t1.wav.list'), gettxt('timit.t1.lab.list'), 'temp', ...
%   16e3, 'REVERB-POOL-1', {'A','B'}, 50000, 2, [60 120], [-10 10])
%
% % recreating files from a filename
% batchaddspeechtonoise('../QUT-NOISE', '../QUT-NOISE/labels', ... 
%   '../QUT-NOISE/impulses', '/work/SAIVT/TIMIT/ORIGCD/timit/', ...
%   gettxt('timit.t1.wav.list'), gettxt('timit.t1.lab.list'), 'temp', ...
%   16e3, { 'CAR-WINDOWNB-1_sA_l060_n+00_i74487_x82dbf.wav', ...  
%     'STREET-CITY-1_sA_l060_n-05_i66207_xf9491.wav' }, ... 
%   'recreate') 

if ~exist('speechpercentv','var')
  % default speechpercentv is 'choose randomly between 0.0 and 1.0'
  speechpercentv=[0 1];
end

if ~exist('concatprob','var')
  % by default 0.5 likelihood of adjacent speech events
  % concatenating each other
  concatprob = 0.5;
end

if ~exist('maxoverlap','var')
  % maximum overlap (in seconds) for concatenated speech events
  maxoverlap = 1;
end

% if splitname='recreate' then we are recreating the file listed in wavname
if strcmp(splitname, 'recreate')

  if ~iscell(wavname)
    wavlist = { wavname };
  else
    wavlist = wavname;
  end

  rg='(^|/)(?<wavname>[^_/]+)[^/]*s(?<splitname>[^_]+)[^/]*l(?<length>[0-9]+)[^/]*[rn](?<snr>[-+][0-9]+)[^/]*i(?<id>[0-9]+)[^/]*x(?<seed>[0-9abcdefABCDEF]+)';
  for i = 1:length(wavlist)
    a = regexp(wavlist{i},rg,'names');

    wavname = a.wavname;

    [noisewavfile, labelfile, impulsefile] = ...
	getbasefiles(wavfolder, labelfolder, impulsefolder, wavname);

    splitname = a.splitname;
    noiselength = str2num(a.length);
    snr = str2num(a.snr);
    seed = hex2dec(a.seed);
    id = str2num(a.id);

    folder = createwavfolder(outfolder, wavname, splitname, noiselength, snr);

    name = createwav(noisewavfile, labelfile, impulsefile, speechfolder, ... 
		     speechlist, speechlablist, splitname, noiselength, ...
		     wantedfs, snr, id, seed, [], ...
		     concatprob, maxoverlap, folder);

    fprintf(1, sprintf('[%6d/%6d] %s\n',i,length(wavlist),name));
  end

% if splitname~='recreate' then we are creating new files  
else

  id=startid;
  total = length(snrs) * length(noiselengths) * sum(countv);
  % create count speech events for each specified parameters
  for snr = snrs
    for noiselength = noiselengths
      % remember the start id for this particular combination of
      % snr and noiselength (use to work out which split to use)
      startid_l_snr = id + 1;

      % get the base files
      [noisewavfile, labelfile, impulsefile] = ...
	  getbasefiles(wavfolder, labelfolder, impulsefolder, wavname);

      % create count files for each speech proportion
      for pi = 1:size(speechpercentv,1)
	speechpercent=speechpercentv(pi,:);
	if length(countv) > 1
	  if length(countv) ~= size(speechpercentv,1)
	    error(['If multiple counts are specified they must match' ...
		   ' the number of speech percent rows']);
	  end
	  count = countv(pi);
	else
	  count = countv;
	end
	fprintf(['Creating %d files with the speech proportions' ...
		 ' between %g and %g\n'], count, speechpercent(1), speechpercent(2)); 
	for i = 1:count
	
	  id = id + 1;

	  % choose the current splitname from the list if provided
	  if iscell(splitname)
	    currentsplitname=splitname{mod((id-startid_l_snr),length(splitname))+1};
	  else
	    currentsplitname=splitname;
	  end
	  
	  folder = createwavfolder(outfolder, wavname, currentsplitname, noiselength, snr);
	  
	  % empty set values get assigned defaults
	  seed=[];
	
	  name = createwav(noisewavfile, labelfile, impulsefile, speechfolder, ... 
			   speechlist, speechlablist, currentsplitname, noiselength, ...
			   wantedfs, snr, id, seed, speechpercent, concatprob, ...
			   maxoverlap, folder);
	  
	  fprintf(1, sprintf('[%3d/%3d] %s\n',id-startid,total,name));
	end
      end
    end
  end
end

function [noisewavfile, labelfile, impulsefile] = ...
    getbasefiles(wavfolder, labelfolder, impulsefolder, wavname)

noisewavfile = [wavfolder '/' wavname '.wav'];
labelfile = [labelfolder '/' wavname '.lab.txt'];
impulsefile = [impulsefolder '/' wavname '.imp.txt'];
if ~exist(impulsefile,'file')
  impulsefile=[];
end

function folder = createwavfolder(outfolder, wavname, splitname, noiselength, snr)

folder = sprintf('%s/%s/s%s/l%03d/n%+03d', outfolder, wavname, ...
		 splitname, noiselength, snr);
if ~exist(folder,'dir')
  mkdir(folder)
end

function name = createwav(noisewavfile, labelfile, impulsefile, speechfolder, ... 
			  speechlist, speechlablist, splitname, noiselength, ...
			  wantedfs, snr, id, seed, speechpercent, concatprob, ...
			  maxoverlap, folder) 

% because speech percent is not precise, we loop until we get a
% file within the speechpercent bounds (if specified)
while 1

   % create noisy speech event
   [speech,fs,name,tlabels,elabels,meta] = ...
       addspeechtonoise(noisewavfile,labelfile, impulsefile, speechfolder, ...
				 speechlist, speechlablist, splitname, noiselength, ...
				 wantedfs, snr, id, seed, speechpercent, concatprob, ...
			         maxoverlap);

   % speechpercent can be empty (not specified), a single number, 
   %   or [min max] expressed as fractions
   % if it is [min max] we want to check that it actual is
   %   within the range
   if size(speechpercent,2) < 2 | ...
	 ( str2num(meta.PercentSpeech) >= speechpercent(1)*100 & ...
	   str2num(meta.PercentSpeech) <= speechpercent(2)*100 )
     break
   end

end

% save wav file
warning off;
wavwrite(speech,fs,16,[folder '/' name '.wav']);
warning on;

% save label files
writelabels(tlabels,[folder '/' name '.timitlab']);
writelabels(elabels,[folder '/' name '.eventlab']);

% save meta file
writestructcsv(meta, [folder '/' name '.meta']);
