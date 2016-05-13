function l = getspeechlength(speechfile)

% remove channel specifier, if provided
speechfile = regexprep(speechfile,':.$','');

% open speechfile
[data,fs] = readaudio(speechfile);

% calculate length
l = length(data) / fs;

