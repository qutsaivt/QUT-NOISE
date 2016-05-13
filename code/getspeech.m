function [data,fs,times,activebounds,channel,labels] = getspeech(speechfile, speechlabelfile, wantedfs, imp, activemode)

% activemode can be 'segments', meaning that speech is not active between segments returned from
% speechlabelfile (or activlev) - This is the default. Or it can be 'bounds', meaning that gaps
% between speech events from speechlabelfile (or activlev) are ignored and considered to remain
% active from the start of the first event to the end of the last.

if (~exist('activemode','var') | isempty(activemode))
   % assume speech is only active when the speechlabelfile (or activlev) says so
   activemode='segments';
end

% get channel and speechfile separately
channel = regexp(speechfile,':.$','match');
if strcmp(channel,':r') | strcmp(channel,':2') | strcmp(channel,':b')
   channel = 2;
else
   channel = 1;
end
speechfile = regexprep(speechfile,':.$','');

% read in specified speechfile
[data,fs] = readaudio(speechfile);

% choose appropriate channel
data = data(:,channel);

if strcmp(speechlabelfile,'activlev')
   % use voicebox's activlev to calculate active speech portions
   [l,a,f,vad]=activlev(data,fs);

   % convert into array of start and end times
   times = [];
   active = false;
   labels = [];
   for f = 1:length(vad)
       if vad(f) & ~active
       	  active = true;
	  startf = f;
       elseif ~vad(f) & active
          active = false;
	  endf = f - 1;
	  label.text = 'speech';
	  label.time = [startf-1 endf-1]; % first frame should be 0, not 1
	  labels = [labels; label];
       end
   end
   if active
       endf = length(vad);
       label.text = 'speech';
       label.time = [startf-1 endf-1]; % first frame should be 0, not 1
       labels = [labels; label];
   end
else
   % open label file to identify speech start and end points
   % (assume label times are in samples using the same frame-rate as the audio)
   labels = getlabels(speechlabelfile);
end
times = vertcat(labels.time);
  
% decimate file (if needed)
if fs ~= wantedfs 
  if mod(fs,wantedfs) == 0
    data = decimate(data,fs/wantedfs,'FIR');
    fs = wantedfs;
    
    % convert times into new fs
    times = times .* wantedfs/fs
  else
    error(sprintf('conversion of %d Hz to %d Hz not supported',fs, ...
		  wantedfs));
  end
end

% convolve clean speech with impulse response of room (if needed)
if length(imp) > 1 
  data = fftfilt(imp,data);
end

% get active bounds (+1 converts back to frames from times)
activebounds = [ min(times(:,1)) max(times(:,2)) ] + 1;

% calculate average energy of active portion of the speech file
if strcmp(activemode,'bounds')
  activerange=[activebounds(1):activebounds(2)];
elseif strcmp(activemode,'segments')
  activerange=[];
  for s = 1:size(times,1)
    activerange=[activerange, [times(s,1):times(s,2)] + 1];
  end
end
activedata=data(activerange);
activespeechenergy=sum(activedata.*activedata) / length(activedata);

% calculate multiplier to match desired -26 dBov speech energy
dBov=-26; desiredspeechenergy=1.0*10^(dBov/10);
data = data .* sqrt(desiredspeechenergy/activespeechenergy);

% % sanity checks (desiredspeechenergy should match activespeechenergy)
% activedata=data(activerange);
% desiredspeechenergy
% allspeechenergy=sum(data.*data) / length(data)
% activespeechenergy=sum(activedata.*activedata) / length(activedata)

