function [noise,fs,noisename,imp,rstart] = getnoisydata(noisywavfilename,labelfilename,noiselength,wantedfs,impulsefile,snr)

% load labelfile information
labels = getlabels(labelfilename);
labeltext = {labels.text};
times = vertcat(labels.time);

% find start time
start = min(min(times(strcmp(labeltext,'start'),:)));

% ignore the first 5 minutes (used for noise training)
start = start + 5*60;

% find finish time
finish = max(max(times(strcmp(labeltext,'finish'),:)));

% check for bad times
bad = times(~cellfun(@isempty,strfind(labeltext,'bad')),:);

% choose random time between start and finish-noiselength
% until doesn't intersect with bad times
while true
  rstart=floor((rand(1)*(finish-noiselength-start))+start);

  if sum(rstart < bad(:,2) & rstart+noiselength > bad(:,1)) == 0
    break
  end
end

% load head of wav file to get fs
info = audioinfo(noisywavfilename);
fs = info.SampleRate;

% use fs and rstart to extract relevant portion of wav file
[noise,fs] = audioread(noisywavfilename,[floor(rstart*fs+1),ceil((rstart+noiselength)*fs+1)]);

% load the impulse response if provided
if ~isempty(impulsefile)
  imp = load(impulsefile,'-ascii');
  imp = imp(:,1)';
else
  imp = [1];
end

% only take the left channel of the noise
noise = noise(:,1);

% decimate the audio and impulse if needed
if exist('wantedfs','var')
  if fs ~= wantedfs 
    if mod(fs,wantedfs) == 0
      noise = decimate(noise,fs/wantedfs,'FIR');
      if length(imp) > 1
	imp = decimate(imp,fs/wantedfs,'FIR');
      end
      fs = wantedfs;
    else
      noise = resample(noise,wantedfs,fs);
      %error(sprintf('Cannot decimate %d to %d Hz. Not yet implemented.',fs,wantedfs));
    end
  end
end

% generate label from filename, start time and noiselength
[path, noisename] = fileparts(noisywavfilename);

% if snr specified, scale noise to match snr, assuming speech will be -26 dBov
if exist('snr','var') & ~isempty(snr)
 
  % calculate desired average speech energy (as -26 dBov)
  dBov=-26;
  desiredspeechenergy=1.0*10^(dBov/10);

  % calculate desired average noise energy using SNR
  desirednoiseenergy=desiredspeechenergy/(10^(snr/10));

  % calculate average energy of noise sample
  noiseenergy=sum(noise.*noise)/length(noise);

  % scale noise to get desired noise energy
  noise = noise .* sqrt(desirednoiseenergy/noiseenergy);

%   % sanity check (should match)
%   desirednoiseenergy
%   noiseenergy=sum(noise.*noise)/length(noise)

end
