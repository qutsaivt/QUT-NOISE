function id = batchaddnoisetospeech(wavfolder, labelfolder, ...
				    impulsefolder, speechfolder, ...
				    speechlist, speechlablist, ...
				    outfolder, wantedfs, wavname, ...
				    snrs, count) 
%
% BATCHADDNOISETOSPEECH adds noise to many speech files
%
%   BATCHADDNOISETOSPEECH(wavfolder, labelfolder,
%     impulsefolder, speechfolder, speechlist, speechlablist,
%     outfolder, wantedfs, wavname, snrs, count) adds a randomly
%     selected section of noise from wavname to 'count' speechfile
%     randomly selected from speechlist. 'snrs' can be a
%     vector to create multiple instances of 'count' files. 
%
%   BATCHADDNOISETOSPEECH(wavfolder, labelfolder,
%     impulsefolder, speechfolder, speechlist, speechlablist,
%     outfolder, wantedfs, speechsequencename, 'recreate') attempts
%     to recreate the  final speech sequence file
%     'speechsequencename'.  'speechsequencename' can also be a
%     cell-array of strings to recreate many files.   
%
% EXAMPLE:
% % creating new files from TIMIT and QUT-NOISE
% batchaddnoisetospeech('../QUT-NOISE', '../QUT-NOISE/labels', ... 
%   '../QUT-NOISE/impulses', '/work/SAIVT/TIMIT/ORIGCD/timit/', ...
%   gettxt('timit.t1.wav.list'), gettxt('timit.t1.lab.list'), 'temp', ...
%   16e3, 'REVERB-POOL-1', [-10 10], 100)
%
% % creating new files from NIST2008 and QUT-NOISE (using activlev
% % speech detector)
% batchaddnoisetospeech('../QUT-NOISE', '../QUT-NOISE/labels', ... 
%   '../QUT-NOISE/impulses', '/work/SAIVT/NIST2008/', ...
%   gettxt('NIST2008.train.short2.list'), 'activlev', 'temp', ...
%   8e3, 'CAFE-CAFE-1', [-10 10], 5)
%
% % recreating based upon filenames from new TIMIT and QUT-NOISE
% batchaddnoisetospeech('../QUT-NOISE', '../QUT-NOISE/labels', ... 
%   '../QUT-NOISE/impulses', '/work/SAIVT/TIMIT/ORIGCD/timit/', ...
%   gettxt('timit.t1.wav.list'), gettxt('timit.t1.lab.list'), 'temp', ...
%   16e3, {'REVERB-POOL-1/n+10/train/dr4/fdkn0/si1081_ch1_REVERB-POOL-1_n+10_x0ec42.wav', ...
%   'CAFE-CAFE-1/n-05/train/dr6/mpgr1/sx419_ch1_CAFE-CAFE-1_n-05_xfc082.wav'}, ...
%   'recreate')
%
% % recreating based upon filenames from NIST2008 and QUT-NOISE
% batchaddnoisetospeech('../QUT-NOISE', '../QUT-NOISE/labels', ... 
%   '../QUT-NOISE/impulses', '/work/SAIVT/NIST2008/', ...
%   gettxt('NIST2008.test.short3.list'), 'activlev', 'temp', ...
%   8e3, { 'NIST2008/CAFE-CAFE-2/n-10/test/data/short3/ffgoq_ch2_CAFE-CAFE-2_n-10_x1cd85.wav', ...  
%   'NIST2008/REVERB-CARPARK-2/n+00/test/data/short3/ffrch_ch1_REVERB-CARPARK-2_n+00_xa2c7e.wav' }, ... 
%   'recreate') 

% if snrs='recreate' then we are recreating the file listed in wavname
if strcmp(snrs, 'recreate')

  if ~iscell(wavname)
    wavlist = { wavname };
  else
    wavlist = wavname;
  end

  fprintf(['Creating %d files\n'], length(wavlist)); 
  time=tic;

  rg='(n[-+][0-9]+/)(?<speechname>.+)_ch(?<channel>[0-9])_(?<wavname>[^_]+)_n(?<snr>[-+][0-9]+)_x(?<seed>[0-9abcdefABCDEF]+)';
  for i = 1:length(wavlist)
    a = regexp(wavlist{i},rg,'names');

    wavname = a.wavname;

    [noisewavfile, labelfile, impulsefile] = ...
	getbasefiles(wavfolder, labelfolder, impulsefolder, wavname);

    speechname = a.speechname;
    channel = str2num(a.channel);
    snr = str2num(a.snr);
    seed = hex2dec(a.seed);

    % find matching speechfile
    speechfilei = find(~cellfun(@isempty,strfind(speechlist,speechname)));
    if length(speechfilei) > 1
    % if more than one file matches, make sure the channel matches
      if channel == 1
        chan_rg=':[al1]$';
      elseif channel == 2
        chan_rg=':[br2]$';
      end
      speechfilei = speechfilei(find(~cellfun(@isempty,regexp(speechlist(speechfilei),chan_rg))));
    end
    [speechpath,speechname,e] = fileparts(speechlist{speechfilei});
    speechfile = [speechfolder '/' speechlist{speechfilei}];

    if iscell(speechlablist)
      % find matching speechlab
      speechlab = [speechfolder '/' speechlablist{speechfilei}];
    else
      speechlab = speechlablist;
    end

    % create output folder
    folder = createwavfolder(outfolder, wavname, speechpath, snr);

    % create wav
    name = createwav(folder, noisewavfile, labelfile, impulsefile, ...
		     speechfile, speechlab, speechname, wantedfs, ...
		     snr, seed);

    % show progress
    elapsed=toc(time);
    tleft = (elapsed / i) * (length(wavlist) - i);
    minleft = ceil(tleft / 60);
    fprintf(1, sprintf('[%3d/%3d ( %dh %dm left) ] %s\n', ...
			 i,length(wavlist),floor(minleft/60), ...
			 mod(minleft,60),name));
  end

% if snrs~='recreate' then we are creating new files  
else

  if (~exist('count','var') | isempty(count))
     % assume we want to recreate every speech in speechlist
     count = length(speechlist);
  end

  total = length(snrs) * count;

  % get the base files
  [noisewavfile, labelfile, impulsefile] = ...
			 getbasefiles(wavfolder, labelfolder, impulsefolder, wavname);

  % create count speech events for each specified parameters
  for snr = snrs
    % randomize based on current time
    rand('state',rem(now,1)*24*60*60*1000);

    % randomly choose 'count' files from speechlist and speechlablist
    if count < length(speechlist)
      choices = randperm(length(speechlist),count);
      speechlist = speechlist(choices);
      if iscell(speechlablist)
        speechlablist = speechlablist(choices);
      end
    end

    fprintf(['Creating %d files with noise %s and a SNR of %g dB\n'], ...
	     count, wavname, snr); 
    time=tic;

    for i = 1:count
      [speechpath,speechname,e] = fileparts(speechlist{i});
      if iscell(speechlablist)
        speechlab = [speechfolder '/' speechlablist{i}];
      else
        speechlab = speechlablist;
      end
      speechfile = [speechfolder '/' speechlist{i}];

      % create output folder
      folder = createwavfolder(outfolder, wavname, speechpath, snr);

      % create wav
      name = createwav(folder, noisewavfile, labelfile, impulsefile, ...
		       speechfile, speechlab, speechname, wantedfs, ...
		       snr, []);

      % show progress
      elapsed=toc(time);
      tleft = (elapsed / i) * (count - i);
      minleft = ceil(tleft / 60);
      fprintf(1, sprintf('[%3d/%3d ( %dh %dm left) ] %s\n', ...
			   i,count,floor(minleft/60), ...
			   mod(minleft,60),name));
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

function folder = createwavfolder(outfolder, wavname, speechpath, snr)

folder = sprintf('%s/%s/n%+03d/%s/%s', outfolder, wavname, snr, speechpath);
if ~exist(folder,'dir')
  mkdir(folder)
end

function name = createwav(folder, noisewavfile, labelfile, impulsefile, ...
			  speechfile, speechlab, speechname, wantedfs, ...
			  snr, seed)


  [noisyspeech, fs, name, meta, eventlabs, noise, clean] = ...
		 addnoisetospeech(noisewavfile, labelfile, impulsefile, ...
				  speechfile, speechlab, speechname, ...
				  wantedfs, snr, seed);

  % save wav file(s)
  warning off;
  wavwrite(noisyspeech,fs,16,[folder '/' name '.wav']);
  warning on;

  % save event file
  writelabels(eventlabs,[folder '/' name '.eventlab']);

  % save meta file
  writestructcsv(meta, [folder '/' name '.meta']);


