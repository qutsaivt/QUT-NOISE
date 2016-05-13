function [noisyspeech,fs,name,meta,eventlabs,noise,clean] = ...
    addnoisetospeech(noisewavfile, labelfile, impulsefile, ...
		     speechfile, speechlabels, speechname, ...
		     wantedfs, snr, seed)
%
% ADDNOISETOSPEECH adds noise to an existing speech file
%
%   noisyspeech = ADDNOISETOSPEECH(noisewavfile, labelfile, ...
%     impulsefile, speechfile, speechlabels, speechname, 
%     wantedfs, snr) adds a randomly selected section of noise 
%     from 'noisewavfile' to 'speechfile' at a signal-to-noise 
%     ratio 'snr'  (in dB). If 'speechfile' ends with ':<channel>',
%     then that channel will be used (l/r,1/2, or a/b can be used
%     for channel. 'speechlabel' defines the active portions of 
%     'speechfile'. If unknown, 'speechlabel' can be provided as 
%     'activlev', which will use ITU-T P.56 VAD to determine the 
%     active portions. 'speechname' will provide the unique name
%     for the speech file to annotate the final filename, 
%     if [], the basename of 'speechfile' will be used.
%
%   noisyspeech = ADDNOISETOSPEECH(..., seed)  creates a noisy
%     speech file according to the seed provided (this is used to
%     make sure the outcome of the random processes are the
%     same. Otherwise the seed will be chosen randomly.
%
%   [noisyspeech[, fs[, name[, meta]]]] =
%     ADDNOISETOSPEECH(...) returns other optional variables
%     generated in the creation of the noisy speech sequence.
%
% EXAMPLE:
% 
% % doing everything randomly
% [speech, fs, name] = ...
%  addnoisetospeech('../QUT-NOISE/CAFE-CAFE-1.wav', ...
%  '../QUT-NOISE/labels/CAFE-CAFE-1.lab.txt', [], ...
%  '/work/SAIVT/TIMIT/ORIGCD/timit/test/dr1/faks0/sa1.wav', ...
%  '/work/SAIVT/TIMIT/ORIGCD/timit/test/dr1/faks0/sa1.wrd', ...
%  'test-dr1-faks0-sa1', 16e3, 10); name
%
% % doing everything randomly, using 'activlev' VAD on NIST2008 data
% [speech, fs, name] = ...
%  addnoisetospeech('../QUT-NOISE/CAFE-CAFE-1.wav', ...
%  '../QUT-NOISE/labels/CAFE-CAFE-1.lab.txt', [], ...
%  '/work/SAIVT/NIST2008/test/data/short3/ftcic.sph:a', ...
%  'activlev', [], 8e3, 10); name
%
% % specifying a seed (and including room response)
% [speech, fs, name, meta] = ...
%  addnoisetospeech('../QUT-NOISE/REVERB-POOL-1.wav', ...
%  '../QUT-NOISE/labels/REVERB-POOL-1.lab.txt', ...
%  '../QUT-NOISE/impulses/REVERB-POOL-1.imp.txt', ...
%  '/work/SAIVT/TIMIT/ORIGCD/timit/test/dr1/faks0/sa1.wav', ...
%  '/work/SAIVT/TIMIT/ORIGCD/timit/test/dr1/faks0/sa1.wrd', ...
%  'test-dr1-faks0-sa1', 16e3, 10, hex2dec('23dc1')); name
%
% % saving wav and meta file
% wavwrite(speech,fs,16,[name '.wav']);
% writestructcsv(meta,[name '.meta'],1);

if isempty(speechname)
  [path, speechname] = fileparts(speechfile);
end   

if (~exist('seed','var') | isempty(seed))
  % randomize based on current time
  rand('state',rem(now,1)*24*60*60*1000);
  % choose a random seed by default
  seed = floor(rand(1)*2^20);
end

% initialise random numbers using seed
rand('state',seed);

% get random segment from noisy file (make sure noise length is slightly more than speech)
[noise,fs,noisename,imp,nstart] = ...
    getnoisydata(noisewavfile, labelfile, getspeechlength(speechfile) + 0.01, wantedfs, ...
			       impulsefile, snr);

% load clean speech from speechfile
[clean,fs,times,active,channel,labels] = ...
     getspeech(speechfile, speechlabels, ...
     	       wantedfs, imp);

% add clean speech to noise
noise = noise(1:length(clean));
noisyspeech=clean + noise;
% clip resulting noisyspeech to [-1 1]
% (only noise should get clipped due to the speech being at -26dBov)
noisyspeech(noisyspeech > 1) = 1;
noisyspeech(noisyspeech < -1) = -1;

% format the resulting noisyspeech label
name = sprintf('%s_ch%d_%s_n%+03d_x%05x', speechname, channel, noisename, snr, seed);

% convert labels to times in seconds
eventlabs = [];
for i = 1:length(labels)
  label.text = labels(i).text;
  label.time = labels(i).time ./ fs;
  eventlabs = [eventlabs; label];
end

% create metadata structure
meta = [];
meta.FileLabel = name;
meta.NoiseLabel = noisename;
[meta.Scenario, r] = strtok(noisename,'-');
[meta.Location, r] = strtok(r,'-');
[meta.Session, r] = strtok(r,'_-');
meta.SNR = sprintf('%+03d', snr);
meta.Seed = sprintf('%05x', seed);
