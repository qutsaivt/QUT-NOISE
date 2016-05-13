function [noisyspeech,fs,name,timitlabels,eventlabels,meta] = ...
    addspeechtonoise(noisewavfile, labelfile, impulsefile, ...
		     speechfolder, speechlist, speechlablist, ...
	             splitname, noiselength, wantedfs, snr, ...
		     id, seed, speechratio, concatprob, ...  
	             maxoverlap)
%
% ADDSPEECHTONOISE creates a noisy speech sequence
%
%   noisyspeech = ADDSPEECHTONOISE(noisewavfile, labelfile, ...
%     speechfolder, speechlist, speechlablist, splitname, ...
%     noiselength, wantedfs, snr, id)  creates a noisy speech
%     sequence of length 'noiselength', signal to noise ratio 'snr'
%     (in dB) located in 'noisewavfile' and annotated in
%     'labelfile'. 'splitname' designates the split for this
%     file. 'id' is only used to label the final file, but should
%     be unique to this file if it is being used as part of a
%     database.
%
%     The TIMIT phrases are randomly chosen from the base folder
%     cell array of strings 'speechlist' (and corresponding TIMIT
%     word-labels 'speechlablist') from the base TIMIT folder
%     'speechfolder'. 
%
%   noisyspeech = ADDSPEECHTONOISE(..., seed)  creates a noisy
%     speech file according to the seed provided (this is used to
%     make sure the outcome of the random processes are the
%     same. Otherwise the seed will be chosen randomly.
%
%   noisyspeech = ADDSPEECHTONOISE(..., seed[, speechratio[,
%     concatprob[, maxoverlap]]]) allows the speechratio,
%     concatprob and maxoverlaps to be specified optionally. If not
%     specified (or defined as []) then speechratio is allocated
%     randomly, concatprob is 0.5 and maxoverlap is 1 second. 'seed'
%     can also be specified as [] if it should be chosen
%     randomly. Both the seed and the speechratio cannot both be
%     specified at the same time, so the seed should be set to []
%     if the speechratio is being specified.
%
%     Note that speechratio is a 'desired' speech ratio, and the
%     actual ratio will be lower by a few percent at least due to
%     the random nature of the speech sequence creation
%     process. Additionally, the speechratio can be specified as a
%     single fraction (ie. 0.15 for 15%) or a range in a
%     two-element vector (ie. [0.75 1.00] for 75-100%. However, the
%     single speech ratio 'r' is really just shorthand for the range
%     '[r (r + 0.01)]'.
%
%   [noisyspeech[, fs[, name[, timitlabels[, eventlabels[, meta]]]]] =
%     ADDSPEECHTONOISE(...) returns other optional variables
%     generated in the creation of the noisy speech sequence.
%
% EXAMPLE:
% 
% % doing everything randomly
% [speech, fs, name] = ...
% addspeechtonoise('qut-noise/2008/CAFE-CAFE-1.wav', ...
% 'qut-noise/2008/labels/CAFE-CAFE-1.lab.txt', [], ...
% '/staticdata/TIMIT/ORIGCD/timit/',gettxt('timit.wav.list'), ...
% gettxt('timit.lab.list'), 'A', 60, 16e3, 10, 1); name 
%
% % specifying a speech ratio
% [speech, fs, name, labels, elabels, meta] = ...
% addspeechtonoise('qut-noise/2008/CAFE-CAFE-1.wav', ...
% 'qut-noise/2008/labels/CAFE-CAFE-1.lab.txt', [], ...
% '/staticdata/TIMIT/ORIGCD/timit/',gettxt('timit.wav.list'), ...
% gettxt('timit.lab.list'), 'A', 60, 16e3, 10, 1, [], 0.20); name, meta 
% 
% % specifying a seed
% [speech, fs, name, labels, elabels, meta] = ...
% addspeechtonoise('qut-noise/2008/CAFE-CAFE-1.wav', ...
% 'qut-noise/2008/labels/CAFE-CAFE-1.lab.txt', [], ...
% '/staticdata/TIMIT/ORIGCD/timit/',gettxt('timit.wav.list'),  ...
% gettxt('timit.lab.list'), 'A', 60, 16e3, 10, 2, hex2dec('9717a')); name
%
% % saving wav, labels and meta file
% wavwrite(speech,fs,16,[name '.wav']);
% writelabels(labels,[name '.timitlab']);
% writelabels(elabels,[name '.eventlab']);
% writestructcsv(meta,[name '.meta'],1);

% you cannot specify a seed and a speech percent at the same time
if (exist('seed','var') & ~isempty(seed) ...
    & exist('speechratio','var') & ~isempty(speechratio))
  error(['You cannot specify a seed and speech percent at the same' ...
	 ' time, as the seed defines the speech percent.']);
end

% if we are aiming for a particular speech percent range, then we
% need to keep choosing a seed until we get a speech percent in
% that range (otherwise we couldn't recreate the file with only the
% seed)
if (exist('seed','var') & ~isempty(seed))
  if (exist('speechratio','var') & ~isempty(speechratio))
    error(['You cannot specify a seed and speech percent at the same' ...
	   ' time, as the seed defines the speech percent.']);
  else
    rand('state',seed);
    speechratio=rand(1);
  end
else
  % randomize based on current time
  rand('state',rem(now,1)*24*60*60*1000);
  if (exist('speechratio','var') & ~isempty(speechratio))
    % speechratio is either a single number, or a range
    % if it is a number change it to a range +0.01 above itself
    if size(speechratio) == 1
      speechratio=[speechratio, speechratio+0.01];
    elseif size(speechratio) ~= 2
      error(['speechevent must either be a single number or a two' ...
	     ' number vector denoting a range']);
    end
    % loop until we get a suitable percent
    while true
      seed = floor(rand(1)*2^20);
      rand('state',seed);
      sp=rand(1);
      if sp >= speechratio(1) && sp <= speechratio(2)
	break
      end
    end
    speechratio=sp;
  else
    % choose a random seed (and speechratio) by default
    seed = floor(rand(1)*2^20);
    rand('state',seed);
    speechratio=rand(1);
  end
end

if (~exist('concatprob','var') | isempty(concatprob))
  % by default 0.5 likelihood of adjacent speech events
  % concatenating each other
  concatprob = 0.5;
end

if (~exist('maxoverlap','var') | isempty(maxoverlap))
  % maximum overlap (in seconds) for concatenated speech events
  maxoverlap = 1;
end

% get random segment from noisy file
[noise,fs,noisename,imp,nstart] = ...
    getnoisydata(noisewavfile, labelfile, noiselength, wantedfs, ...
			       impulsefile, snr);

% initialise variables for holding speech information
speechframes=0; oldspeechframes=0;
noiseframes=length(noise);
speechevents=[];

% locate timit files until over specified speechratio
while speechframes/noiseframes < speechratio

  % choose random timit file from speechlist
  speechi = ceil(rand(1)*length(speechlist));
  speechfile = speechlist{speechi};
  labfile = speechlablist{speechi};

  [data,fs,times,active] = ...
     getspeech([speechfolder '/' speechfile], ...
               [speechfolder './' labfile], ...
     	       wantedfs, imp, 'bounds');

  % remember old speech length for later
  oldspeechframes = speechframes;

  % create timit speech event
  event = [];
  event.file = speechfile;
  event.data = data;
  % record the bounds of the actual speech events
  event.active = active;
  % decide if this speech event is concatenated with the previous
  % and if it is, what overlap occurs
  event.withprevious = (rand(1) > concatprob);
  if event.withprevious
    % min(speechframes,...) protects overlapping the start of the file
    event.overlapprevious = round(rand(1) * min(speechframes,maxoverlap*fs));
    speechframes = speechframes - event.overlapprevious;
  else
    % no concat -> no overlap
    event.overlapprevious = 0;
  end
  % add speech event to list
  speechevents = [speechevents; event];
  speechframes = speechframes + length(data);
end

% remove the last speechevent to ensure we stay under the percent
speechevents = speechevents(1:end-1);
speechframes = oldspeechframes;

% arrange non-concatenated speechevents to have random amounts of 
% silence between them
numsilences = length(speechevents)+1-sum([speechevents.withprevious]);
silences=[rand(1,numsilences)];
% convert to ratio of total silences
silences=round((silences/sum(silences)).*(noiseframes-speechframes));

% initialise timitlabels
timitlabels=[];
% create clean speech vector of same size as noise
clean = zeros(size(noise));
si = 1; % silences index
cur = 1; % current location in clean speech vector
speechclumps = 0; % how many distinct clumps of speech are there
% go through each speech event created above and add to clean
% speech vector
for i = 1:length(speechevents)
  if speechevents(i).withprevious
    % this speech event does concatenate with the previous
    % (this only counts as a new speech clump if at the start of the file)
    if cur == 1
      speechclumps = speechclumps + 1;
    end
    % move cur back to handle overlap with concatenated speech events
    cur = cur - speechevents(i).overlapprevious;
  else
    % move cur without changing underlying vector (ie. add silence)
    cur = cur+silences(si);
    si = si + 1;
    % this is a new speech clump
    speechclumps = speechclumps + 1;
  end
  % record start time
  start=cur;
  data=speechevents(i).data;
  % add the speech data to the clean vector
  clean(cur:cur+length(data)-1) = clean(cur:cur+length(data)-1) + data;
  % increment current location and record end time
  cur = cur+length(data);
  finish = cur-1;
  % create speech label
  label = [];
  label.text = speechevents(i).file;
  label.time = ([start finish] - 1) ./ fs; % frame 1 should match to time 0
  label.active = ( speechevents(i).active - 1 ) ./ fs; % ditto
  timitlabels = [timitlabels; label];
end

% create speech-event labels
firstspeechstart = 0;
speecheventcount = 0;
totalspeechtime = 0;
speechstart = 0;
t = 0; % current time index
eventlabels = [];
for i = 1:length(timitlabels)+1
  if i <= length(timitlabels)
    % record actual start and end times of this speech event
    start=timitlabels(i).time(1) + timitlabels(i).active(1);
    finish=timitlabels(i).time(1) + timitlabels(i).active(2);
  else
    % this iteration is special as it indicates that we have
    % reached the end of the noisy speech sequence, so we simulate
    % a dummy timit event to cause the final speech event and
    % silence to be output 
    start = noiselength;
    finish = noiselength;
  end
  % if there is a gap between the previous speech event and this one
  if t < start
    % if there is a unfinished speech event
    if t > speechstart
      % create a speech event from speechstart to t
      label.text = 'speech';
      label.time = [speechstart t];
      eventlabels = [eventlabels; label];
      speecheventcount = speecheventcount + 1;
      totalspeechtime = totalspeechtime + (t - speechstart);
    end
    % and then a nonspeech event from t to the start of this event
    label.text = 'nonspeech';
    label.time = [t start];
    eventlabels = [eventlabels; label];
    % and record the start of this speech event
    speechstart = start;
    if firstspeechstart == 0
      % record the first speech start event for later
      firstspeechstart = start;
    end
  end
  t = finish;
end

% add clean speech to noise
noisyspeech=noise+clean;
% clip resulting noisyspeech to [-1 1]
% (only noise should get clipped due to the speech being at -26dBov)
noisyspeech(noisyspeech > 1) = 1;
noisyspeech(noisyspeech < -1) = -1;

% format the resulting name
name = sprintf('%s_s%s_l%03d_n%+03d_i%05d_x%05x', noisename, splitname, floor(noiselength), snr, id, seed);

% create metadata structure
meta = [];
meta.ID = sprintf('%05d',id);
meta.FileLabel = name;
meta.NoiseLabel = noisename;
[meta.Scenario, r] = strtok(noisename,'-');
[meta.Location, r] = strtok(r,'-');
[meta.Session, r] = strtok(r,'_-');
meta.Split = splitname;
meta.SNR = sprintf('%+03d', snr);
meta.Length = sprintf('%03d', noiselength);
meta.Seed = sprintf('%05x', seed);
meta.NoiseStart = sprintf('%04d', nstart);
meta.PercentSpeech = sprintf('%02.2f',100*totalspeechtime/noiselength);
meta.SpeechEventCount = sprintf('%02d', speecheventcount);
meta.FirstSpeechLocation = sprintf('%02.5f', firstspeechstart);
